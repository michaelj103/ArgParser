//
//  MBArgumentParser.h
//  HackPlatform
//
//  Created by Michael Brandt on 8/19/15.
//  Copyright © 2015 MJB. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, MBArgumentType) {
    MBArgumentTypeBoolean,                      ///< Argument is either present or not. Default is NO
    MBArgumentTypeString,                       ///< Argument requires an associated string (next argument). Default is nil
};

/// MBArgumentParser can be used to parse command line arguments. Register rules for options and inputs and then parse a list of supplied arguments
/// according to those rules. After parsing, values may be requested. Help text is automatically generated on demand so that you can register a help option to show it
@interface MBArgumentParser : NSObject

- (instancetype)initWithCommandName:(NSString *)name description:(NSString *)description;

/// @brief Register an option for parsing with a name for retrieval and help info. Will replace any previously registered option with the given name
/// @param name A string to register with the parser to retrieve the value of this option after parsing
/// @param type The type of the option to be expected by the parser
/// @param variants The list of possible variants for this option, not including "-" or "--". eg a short and long form like @[@"o", @"output"]
/// @param description Text describing the option for the help info
- (void)registerOptionWithName:(NSString *)name type:(MBArgumentType)type variants:(NSArray *)variants description:(NSString *)description;

/// @brief Registers an input argument for parsing with name for retrieval and help info.
/// Inputs are assumed to be supplied in the order in which they are registered
/// @param name The name of the input
/// @param description Text describing the option for the help info
- (void)registerInputWithName:(NSString *)name description:(NSString *)description;

/// @brief Parse the supplied list of arguments
/// @param arguments An array of NSString values to be parsed according to the registered options
/// @param error An inout error parameter. Should always be set when return value is NO
/// @return boolean indicating success. If NO, there should be an error
- (BOOL)parseArguments:(NSArray *)arguments withError:(NSError **)error;

/// @brief Retrieve the value of a string option after parsing
/// @param name Name of the string option
/// @return String value of the option or nil if unspecified
- (NSString *)valueForStringOption:(NSString *)name;

/// @brief Retrieve the value of a boolean option after parsing
/// @param name Name of the boolean option
/// @return boolean value indicating whether or not the option was specified
- (BOOL)valueForBooleanOption:(NSString *)name;

/// @brief Retrieve the value of a named input after parsing
/// @param name Name of the desired input
/// @return String value of the input or nil if not supplied
- (NSString *)valueForInput:(NSString *)name;

/// @brief Help text to display in response to a help option
- (NSString *)helpInfo;

@end
