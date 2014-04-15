//
//  Localizer.h
//
//  Created by Andy Savage <andy@savage.hk>
//  Copyright (c) 2013 Andy Savage. All rights reserved.
//

#import <Foundation/Foundation.h>

#define APP_LANG_KEY @"app_language"

#define DEFAULT_LANG @"en"
#define DEFAULT_STRINGS_FILE @"strings"
#define DEFAULT_FONTS_FILE @"fonts"
#define DEFAULT_SEPARATOR @"; "

@interface Localizer : NSObject

@property (nonatomic, strong) NSDictionary *availableLanguages;

@property (nonatomic, strong) NSDictionary *strings;
@property (nonatomic, strong) NSArray *stringsFile;

@property (nonatomic, strong) NSDictionary *fonts;
@property (nonatomic, strong) NSArray *fontsFile;

@property (nonatomic, strong) NSString *language; // Set this to a different code to change the language

@property (nonatomic, strong) NSString *separator;
@property (nonatomic, assign) bool removeAtTwoTimes;
@property (nonatomic, assign) bool logging;

+ (Localizer *)instance;

/** Get a string using a key **/
- (NSString *)stringWithKey: (NSString *)key;
+ (NSString *)stringWithKey: (NSString *)key;

/** Get a font using a key **/
+ (UIFont *)fontWithKey:(NSString *)key;

/** Get a text color using a key **/

- (UIImage *)imageNamed: (NSString *)name;
+ (UIImage *)imageNamed: (NSString *)name;

- (NSArray *) imageAnimationArrayWithImageNamed:(NSString *)name numberOfImages:(NSUInteger)numberOfImages;
+ (NSArray *) imageAnimationArrayWithImageNamed:(NSString *)name numberOfImages:(NSUInteger)numberOfImages;

/** Checks if a string exists using a key **/
- (BOOL)objectForKeyExists: (NSString *)key;

/** Get an array using a key **/
- (NSArray *)arrayWithKey: (NSString *)key;
+ (NSArray *)arrayWithKey: (NSString *)key;

- (NSString *)stringWithKey: (NSString *)key atIndex: (int)index;

/** Helper method to determine if the current language is english **/
- (BOOL)isEnglish;

@end
