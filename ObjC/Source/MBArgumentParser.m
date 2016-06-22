//
//  MBArgumentParser.m
//  HackPlatform
//
//  Created by Michael Brandt on 8/19/15.
//  Copyright © 2015 MJB. All rights reserved.
//

#import "MBArgumentParser.h"

#define MB_ARG_PARSER_ERROR_DOMAIN @"com.mjb.MBArgumentParser.errorDomain"

@interface MBOptionInfo : NSObject
@property (readwrite, nonatomic, copy) NSString *name;
@property (readwrite, nonatomic, copy) NSArray *variants;
@property (readwrite, nonatomic, assign) MBArgumentType type;
@property (readwrite, nonatomic, copy) NSString *optionDescription;
@end

@implementation MBOptionInfo
@end

@interface MBInputInfo : NSObject
@property (readwrite, nonatomic, copy) NSString *name;
@property (readwrite, nonatomic, copy) NSString *inputDescription;
@end

@implementation MBInputInfo
@end

@implementation MBArgumentParser {
    NSString *_commandName;
    NSString *_descriptionText;
    NSMutableDictionary *_registeredOptions;    //option name : MBOptionInfo, no particular order
    NSMutableArray *_registeredInputs;          //just names, in order
    NSMutableDictionary *_optionValues;         //option name : associated value
    NSMutableDictionary *_inputValues;          //input name : value
}

- (instancetype)initWithCommandName:(NSString *)name description:(NSString *)description {
    NSAssert(name != nil && [name length] > 0, @"Must specify a command name");
    self = [super init];
    if (self) {
        _commandName = [name copy];
        _descriptionText = [description copy];
        _registeredOptions = [NSMutableDictionary dictionary];
        _registeredInputs = [NSMutableArray array];
        _optionValues = [NSMutableDictionary dictionary];
        _inputValues = [NSMutableDictionary dictionary];
    }
    
    return self;
}

- (void)registerOptionWithName:(NSString *)name type:(MBArgumentType)type variants:(NSArray *)variants description:(NSString *)description {
    //validation
    NSAssert(name != nil, @"MBArgumentParser: Must specify a name to register an option");
    NSAssert(variants != nil && [variants count] > 0, @"MBArgumentParser: Must specify at least one variant to register an option");
    for (NSString *optionVariant in variants) {
        NSAssert([optionVariant length] > 0, @"MBArgumentParser: Variants may not be empty strings");
    }
    
    //remove any existing values for this option since we're re-registering it
    [_registeredOptions removeObjectForKey:name];
    [_optionValues removeObjectForKey:name];
    
    //make sure no other options contain matching variants
    for (NSString *variant in variants) {
        NSAssert([self _registeredOptionForString:variant] == nil, @"MBArgumentParser: Option \'%@\' registered multiple times", variant);
    }
    
    MBOptionInfo *optionInfo = [[MBOptionInfo alloc] init];
    [optionInfo setName:name];
    [optionInfo setVariants:variants];
    [optionInfo setType:type];
    [optionInfo setOptionDescription:description];
    
    _registeredOptions[name] = optionInfo;
}

- (void)registerInputWithName:(NSString *)name description:(NSString *)description {
    //validation
    NSAssert(name != nil, @"MBArgumentParser: Must specify a name to register an input");
    
    //remove any existing values for this option since we're re-registering it
    [_registeredInputs removeObject:name];
    [_inputValues removeObjectForKey:name];
    
    MBInputInfo *inputInfo = [[MBInputInfo alloc] init];
    [inputInfo setName:name];
    [inputInfo setInputDescription:description];
    
    [_registeredInputs addObject:inputInfo];
}

- (NSString *)valueForStringOption:(NSString *)name {
    //validation
    MBOptionInfo *optionInfo = _registeredOptions[name];
    NSAssert(optionInfo != nil, @"MBArgumentParser: requested value for unregistered option: %@", name);
    NSAssert([optionInfo type] == MBArgumentTypeString, @"MBArgumentParser: requested string for non-string option %@", name);
    
    NSString *stringValue = _optionValues[name];
    
    return stringValue;
}

- (BOOL)valueForBooleanOption:(NSString *)name {
    //validation
    MBOptionInfo *optionInfo = _registeredOptions[name];
    NSAssert(optionInfo != nil, @"MBArgumentParser: requested value for unregistered option: %@", name);
    NSAssert([optionInfo type] == MBArgumentTypeBoolean, @"MBArgumentParser: requested boolean for non-boolean option %@", name);
    
    BOOL boolValue = [_optionValues[name] boolValue];
    
    return boolValue;
}

- (NSString *)valueForInput:(NSString *)name {
    //validation
    BOOL isRegistered = NO;
    for (MBInputInfo *inputInfo in _registeredInputs) {
        if ([name isEqualToString:[inputInfo name]]) {
            isRegistered = YES;
            break;
        }
    }
    NSAssert(name != nil && isRegistered, @"MBArgumentParser: requested value for unregistered input: %@", name);
    
    NSString *stringValue = _inputValues[name];
    
    return stringValue;
}

//get the mutable string of "variant1, variant2,... description"
- (NSMutableString *)_stringForOptionInfo:(MBOptionInfo *)optionInfo descriptionStartIdx:(NSUInteger *)descriptionIdx {
    NSMutableString *builtString = [NSMutableString stringWithString:@""];
    
    for (NSString *optionVariant in [optionInfo variants]) {
        if ([builtString length] > 0) {
            [builtString appendString:@", "];
        }
        
        if ([optionVariant length] == 1) {
            [builtString appendString:@"-"];
        } else {
            [builtString appendString:@"--"];
        }
        [builtString appendFormat:@"%@", optionVariant];
    }
    
    if ([optionInfo type] == MBArgumentTypeString) {
        [builtString appendFormat:@" <%@>", [optionInfo name]];
    }
    [builtString appendString:@" "];
    NSUInteger startDescription = [builtString length];
    [builtString appendFormat:@"%@", [optionInfo optionDescription]];
    
    if (descriptionIdx) {
        *descriptionIdx = startDescription;
    }
    
    return builtString;
}

//get the mutable string of "input_name description"
- (NSMutableString *)_stringForInputInfo:(MBInputInfo *)inputInfo descriptionStartIdx:(NSUInteger *)descriptionIdx {
    NSMutableString *builtString = [NSMutableString stringWithFormat:@"%@ ", [inputInfo name]];
    NSUInteger startDescription = [builtString length];
    [builtString appendFormat:@"%@", [inputInfo inputDescription]];
    
    if (descriptionIdx) {
        *descriptionIdx = startDescription;
    }
    
    return builtString;
}

- (NSString *)helpInfo {
    BOOL hasOptions = [[_registeredOptions allKeys] count] > 0;
    BOOL hasInputs = [_registeredInputs count] > 0;
    
    // usage info first
    NSMutableString *helpInfo = [NSMutableString stringWithFormat:@"\nUsage: %@", _commandName];
    if (hasOptions) {
        [helpInfo appendString:@" [options]"];
    }
    for (MBInputInfo *info in _registeredInputs) {
        [helpInfo appendFormat:@" <%@>", [info name]];
    }
    [helpInfo appendString:@"\n"];
    
    // description text next
    if (_descriptionText && [_descriptionText length] > 0) {
        [helpInfo appendFormat:@"\n%@\n", _descriptionText];
    }
    
    //print inputs
    if (hasInputs) {
        [helpInfo appendString:@"\nInputs:\n"];
        //print options and their descriptions. align descriptions to longest option + 5 spaces
        NSMutableArray *strings = [NSMutableArray array];
        NSMutableArray *startIndexes = [NSMutableArray array];
        NSUInteger maxStartIdx = 0;
        for (MBInputInfo *info in _registeredInputs) {
            NSUInteger startIdx = 0;
            NSMutableString *infoString = [self _stringForInputInfo:info descriptionStartIdx:&startIdx];
            [strings addObject:infoString];
            [startIndexes addObject:@(startIdx)];
            maxStartIdx = (startIdx > maxStartIdx) ? startIdx : maxStartIdx;
        }
        
        NSUInteger desiredDescriptionStart = maxStartIdx + 4;
        for (NSUInteger i = 0; i < [strings count]; i++) {
            NSMutableString *nextString = [strings objectAtIndex:i];
            NSUInteger startIdx = [[startIndexes objectAtIndex:i] unsignedIntegerValue];
            while (startIdx < desiredDescriptionStart) {
                [nextString insertString:@" " atIndex:startIdx];
                startIdx++;
            }
            
            [helpInfo appendString:@"   "];     //indent
            [helpInfo appendFormat:@"%@\n", nextString];
        }
    }
    
    //print options
    if (hasOptions) {
        [helpInfo appendString:@"\nOptions:\n"];
        //print options and their descriptions. align descriptions to longest option + 5 spaces
        NSMutableArray *strings = [NSMutableArray array];
        NSMutableArray *startIndexes = [NSMutableArray array];
        NSUInteger maxStartIdx = 0;
        for (MBOptionInfo *info in [_registeredOptions allValues]) {
            NSUInteger startIdx = 0;
            NSMutableString *optionString = [self _stringForOptionInfo:info descriptionStartIdx:&startIdx];
            [strings addObject:optionString];
            [startIndexes addObject:@(startIdx)];
            maxStartIdx = (startIdx > maxStartIdx) ? startIdx : maxStartIdx;
        }
        
        NSUInteger desiredDescriptionStart = maxStartIdx + 4;
        for (NSUInteger i = 0; i < [strings count]; i++) {
            NSMutableString *nextString = [strings objectAtIndex:i];
            NSUInteger startIdx = [[startIndexes objectAtIndex:i] unsignedIntegerValue];
            while (startIdx < desiredDescriptionStart) {
                [nextString insertString:@" " atIndex:startIdx];
                startIdx++;
            }
            
            [helpInfo appendString:@"   "];     //indent
            [helpInfo appendFormat:@"%@\n", nextString];
        }
    }
    
    return helpInfo;
}

#pragma mark - Parsing

- (NSError *)_parserErrorWithString:(NSString *)errorString {
    NSDictionary *errorInfo = @{ NSLocalizedDescriptionKey : errorString };
    NSError *parseError = [NSError errorWithDomain:MB_ARG_PARSER_ERROR_DOMAIN code:1 userInfo:errorInfo];
    return parseError;
}

//finds matching options for the given string, character by character
- (NSArray *)_registeredOptionsForMultiOptionString:(NSString *)stringToMatch {
    NSMutableArray *outArray = [NSMutableArray array];
    for (NSUInteger i = 0; i < [stringToMatch length]; i++) {
        NSString *substring = [stringToMatch substringWithRange:NSMakeRange(i, 1)];
        MBOptionInfo *info = [self _registeredOptionForString:substring];
        if (info && [info type] == MBArgumentTypeBoolean) {
            [outArray addObject:info];
        } else {
            //not found
            outArray = nil;
            break;
        }
    }
    return outArray;
}

- (MBOptionInfo *)_registeredOptionForString:(NSString *)stringToMatch {
    MBOptionInfo *outInfo = nil;
    for (MBOptionInfo *info in [_registeredOptions allValues]) {
        for (NSString *variant in [info variants]) {
            if ([stringToMatch isEqualToString:variant]) {
                outInfo = info;
                break;
            }
        }
    }
    
    return outInfo;
}

- (BOOL)parseArguments:(NSArray *)arguments withError:(NSError *__autoreleasing *)error {
    [_optionValues removeAllObjects];
    [_inputValues removeAllObjects];
    
    BOOL success = YES;
    NSError *outErr = nil;
    
    NSUInteger inputIdx = 0;
    for (NSUInteger i = 0; i < [arguments count]; i++) {
        NSString *arg = [arguments objectAtIndex:i];
        NSString *optionToMatch = nil;
        BOOL multiOption = NO;
        if ([arg hasPrefix:@"--"]) {
            optionToMatch = [arg substringFromIndex:2];
        } else if ([arg hasPrefix:@"-"]) {
            optionToMatch = [arg substringFromIndex:1];
            if ([optionToMatch length] > 1) {
                multiOption = YES;
            }
        }
        
        if (optionToMatch && multiOption) {
            NSArray *optionInfos = [self _registeredOptionsForMultiOptionString:optionToMatch];
            if (optionInfos) {
                for (MBOptionInfo *optionInfo in optionInfos) {
                    NSString *name = [optionInfo name];
                    _optionValues[name] = @YES;
                }
            } else {
                //abort if any not found
                outErr = [self _parserErrorWithString:[NSString stringWithFormat:@"Invalid or unrecognized option in %@", arg]];
                break;
            }
        } else if (optionToMatch) {
            //we're looking for a matching option for a full string
            MBOptionInfo *optionInfo = [self _registeredOptionForString:optionToMatch];
            if (optionInfo) {
                MBArgumentType optionType = [optionInfo type];
                if (optionType == MBArgumentTypeBoolean) {
                    NSString *name = [optionInfo name];
                    _optionValues[name] = @YES;
                } else if (optionType == MBArgumentTypeString) {
                    i++;    //next argument
                    if (i >= [arguments count]) {
                        //abort, no subsequent string!
                        outErr = [self _parserErrorWithString:[NSString stringWithFormat:@"Option %@ expects an input", arg]];
                        break;
                    }
                    NSString *argValue = [[arguments objectAtIndex:i] copy];
                    NSString *name = [optionInfo name];
                    _optionValues[name] = argValue;
                }
            } else {
                //abort if not found
                outErr = [self _parserErrorWithString:[NSString stringWithFormat:@"Unrecognized option: %@", arg]];
                break;
            }
        } else {
            //must be an input
            if (inputIdx >= [_registeredInputs count]) {
                //abort if too many inputs
                outErr = [self _parserErrorWithString:@"Too many input arguments"];
                break;
            }
            
            NSString *input = [arguments objectAtIndex:i];
            MBInputInfo *inputInfo = [_registeredInputs objectAtIndex:inputIdx];
            NSString *name = [inputInfo name];
            _inputValues[name] = input;
            inputIdx++;
        }
    }
    
    if (outErr) {
        success = NO;
    }
    
    if (error) {
        *error = outErr;
    }
    
    return success;
}

@end
