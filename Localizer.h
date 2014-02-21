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

@property (nonatomic, strong) NSDictionary *strings;
@property (nonatomic, strong) NSString *language;
@property (nonatomic, strong) NSString *file;
@property (nonatomic, strong) NSString *separator;
@property (nonatomic, assign) bool removeAtTwoTimes;
@property (nonatomic, assign) bool logging;

+ (Localizer *)instance;

/** Loads strings from a file in the apple dictionary format **/
- (BOOL)loadStringFile: (NSString *)filename;

/** Change the language used in the localizer using a two string lang code **/
- (BOOL)changeLanguage: (NSString *)lang;

/** Get a string using a key **/
- (NSString *)stringWithKey: (NSString *)key;
+ (NSString *)stringWithKey: (NSString *)key;

- (UIImage *)imageWithName: (NSString *)name;
+ (UIImage *)imageWithName: (NSString *)name;

- (NSArray *) imageAnimationArrayWithName:(NSString *)name numberOfImages:(NSUInteger)numberOfImages;
+ (NSArray *) imageAnimationArrayWithName:(NSString *)name numberOfImages:(NSUInteger)numberOfImages;

/** Checks if a string exists using a key **/
- (BOOL)objectForKeyExists: (NSString *)key;

/** Get an array using a key **/
- (NSArray *)arrayWithKey: (NSString *)key;
+ (NSArray *)arrayWithKey: (NSString *)key;

- (NSString *)stringWithKey: (NSString *)key atIndex: (int)index;

/** Helper method to determine if the current language is english **/
- (BOOL)isEnglish;

@end
