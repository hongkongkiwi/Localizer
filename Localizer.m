//
//  Localizer.m
//
//  Created by Andy Savage <andy@savage.hk>
//  Copyright (c) 2013 Andy Savage. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Localizer.h"

@implementation Localizer {
    
}

static Localizer *_globalInstance;

+ (Localizer *)instance {
    if(_globalInstance == nil){
        _globalInstance = [[Localizer alloc] init];
        
        [_globalInstance loadStringFile: DEFAULT_FILE];
    }
    return _globalInstance;
}

- (id)init {
    self = [super init];
    if(self){
        self.language = [[NSUserDefaults standardUserDefaults] valueForKey: APP_LANG_KEY];
        if(_language == nil){
            NSString *syslang = [[NSLocale preferredLanguages] objectAtIndex:0];
            if (self.logging) {
                NSLog(@"Phone language : %@", syslang);
            }
//            if([syslang compare: @"zh-Hans"] == NSOrderedSame || [syslang compare: @"zh-Hant"] == NSOrderedSame){
//                self.language = @"zh";
//            } else {
//                self.language = @"en";
//            }

            // overwrite to english
            self.language = @"en";
            
            [[NSUserDefaults standardUserDefaults] setValue:self.language forKey: APP_LANG_KEY];
        }
        
        self.file = DEFAULT_FILE;
        self.separator = DEFAULT_SEPARATOR;
        self.removeAtTwoTimes = YES;
        self.logging = YES;
    }
    return self;
}

- (BOOL) loadStringFile: (NSString *)filename {
    NSString *fullname = [NSString stringWithFormat: @"%@_%@", filename, self.language];
    
    NSString *strings_path = [[NSBundle mainBundle] pathForResource:fullname ofType:@"txt"];
    
    if (strings_path == nil) {
        if (self.logging) {
            NSLog(@"Localizer: ERROR - Unable to get path for file %@", fullname);
        }
        return false;
    }
    
    NSDictionary *loadedDict = [NSDictionary dictionaryWithContentsOfFile:strings_path];
    if (!loadedDict) {
        if (self.logging) {
            NSLog(@"Localizer: ERROR - Tried to load invalid strings file %@", filename);
        }
        return NO;
    }
    
    if (self.strings) {
        NSMutableDictionary *newArray = self.strings.mutableCopy;
        [newArray addEntriesFromDictionary:loadedDict];
        self.strings = newArray;
    } else {
        self.strings = loadedDict;
    }
    
    self.file = filename;
    if ([self.strings count] == 0) {
        if (self.logging) {
            NSLog(@"Localizer: WARNING - No strings found in %@", self.strings);
        }
        return NO;
    }
    
    return YES;
}

- (BOOL)changeLanguage: (NSString *)lang {
    NSString *oldLang = self.language;
    self.language = lang;
    
    if([self loadStringFile: _file]){
        if (self.logging) {
            NSLog(@"Localizer Error: Unable to create dictionary for file %@", _file);
        }
        
        self.language = oldLang;
        return false;
    }
    
    return true;
}

- (NSString *)stringWithKey: (NSString *)key{
    NSString *string = _strings[key];
    if(string){
        return string;
    } else {
        if (self.logging) {
            NSLog(@"Localizer Warning: Couldn't find string for key %@", key);
        }
        return nil;
    }
}

+ (NSString *)stringWithKey:(NSString *)key {
    return [[Localizer instance] stringWithKey:key];
}

- (UIImage *) imageNamed:(NSString *)name {
    return [self ImageNamed:name imageNumber:-1];
}


+ (UIImage *) imageNamed: (NSString *)name {
    return [[Localizer instance] imageNamed:name];
}

- (UIImage *) ImageNamed:(NSString *)name imageNumber:(NSUInteger)imageNumber {
    // Save path extension
    NSString *extension = [name pathExtension];
    // Remove path extension
    name = [name stringByDeletingPathExtension];
    
    NSString *atTwoTimes = @"";
    // Check if @2x exists
    if ([name rangeOfString:@"@2x"].location != NSNotFound) {
        if (self.removeAtTwoTimes) {
            if (self.logging) {
                NSLog(@"Localizer: Warning image name to find contains @2x in the name but we removed it");
            }
            name = [name stringByReplacingOccurrencesOfString:@"@2x" withString:@""];
        } else {
            atTwoTimes = @"@2x";
        }
    }
    
    // If this is going to be used in an image array then add the image number
    NSString *imageText = @"";
    if (imageNumber > -1) {
        imageText = [NSString stringWithFormat:@"%lu_", (unsigned long)imageNumber];
    }
    
    // Check the localized name with users current language
    NSString *localizedName = [NSString stringWithFormat:@"%@_%@%@%@.%@", name, imageText, self.language, atTwoTimes, extension];
    UIImage *image = [UIImage imageNamed:localizedName];
    
    if (!image) {
        // Check the localized name with no language (default) name
        localizedName = [NSString stringWithFormat:@"%@%@%@.%@", name, imageText, atTwoTimes, extension];
        image = [UIImage imageNamed:localizedName];
        if (!image) {
            // Couldn't find any image at all tell the user
            if (self.logging) {
                NSLog(@"Localizer Warning: Couldn't find any image named %@", localizedName);
            }
            image = nil;
        // Check whether the image was a default (just so we can warn the user)
        } else if (![self.language isEqualToString:@"en"]) {
            if (self.logging) {
                NSLog(@"Localizer Warning: Couldn't find image named %@ using default english image", localizedName);
            }
        }
    }
    
    return image;
}

// Returns a localized image array suitable for passing to an animate function
- (NSArray *) imageAnimationArrayWithImageNamed:(NSString *)name numberOfImages:(NSUInteger)numberOfImages {
    NSMutableArray *imageArray = [NSMutableArray new];
    for (unsigned int i = 0; i < numberOfImages; i++) {
        [self ImageNamed:name imageNumber:i];
    }
    return imageArray;
}

+ (NSArray *) imageAnimationArrayWithImageNamed:(NSString *)name numberOfImages:(NSUInteger)numberOfImages {
    return [[Localizer instance] imageAnimationArrayWithImageNamed:name numberOfImages:numberOfImages];
}

- (BOOL)objectForKeyExists: (NSString *)key {
    return ([_strings objectForKey:key] != nil);
}

- (NSArray *)arrayWithKey: (NSString *)key {
    NSString *string = [self stringWithKey:key];
    return ([string length] > 0) ? [string componentsSeparatedByString: _separator] : nil;
}

+ (NSArray *)arrayWithKey: (NSString *)key {
    return [[Localizer instance] arrayWithKey:key];
}

- (NSString *)stringWithKey: (NSString *)key atIndex: (int)index{
    NSArray *array = [self arrayWithKey:key];
    
    if(!array || [array count] <= index) return key;
    
    return [array objectAtIndex:index];
}

- (BOOL)isEnglish {
    return ([self.language compare: @"en"] == NSOrderedSame);
}



@end
