//
//  Localizer.h
//
//  Created by Andy Savage <andy@savage.hk>
//  Copyright (c) 2013 Andy Savage. All rights reserved.
//

#import <Foundation/Foundation.h>

#define APP_LANG_KEY @"app_language"

#define DEFAULT_LANG @"en"
#define DEFAULT_FILE @"strings"
#define DEFAULT_SEPARATOR @"; "

@interface Localizer : NSObject

@property (strong, nonatomic) NSDictionary *strings;
@property (strong, nonatomic) NSString *language;
@property (strong, nonatomic) NSString *file;
@property (strong, nonatomic) NSString *separator;

+ (Localizer *)instance;

/** Loads strings from a file in the apple dictionary format **/
- (BOOL)loadStringFile: (NSString *)filename;

/** Change the language used in the localizer using a two string lang code **/
- (BOOL)changeLanguage: (NSString *)lang;

/** Get a string using a key **/
- (NSString *)stringWithKey: (NSString *)key;

/** Checks if a string exists using a key **/
- (BOOL)objectForKeyExists: (NSString *)key;

/** Get an array using a key **/
- (NSArray *)arrayWithKey: (NSString *)key;

- (NSString *)stringWithKey: (NSString *)key atIndex: (int)index;

/** Helper method to determine if the current language is english **/
- (BOOL)isEnglish;


@end
