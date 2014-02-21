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
            NSLog(@"Phone language : %@", syslang);
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
    }
    return self;
}

- (BOOL) loadStringFile: (NSString *)filename {
    
    NSString *fullname = [NSString stringWithFormat: @"%@_%@", filename, self.language];
    
    NSString* strings_path = [[NSBundle mainBundle] pathForResource:fullname ofType:@"txt"];
    
    if(strings_path == nil){
        NSLog(@"Unable to get path for file %@", fullname);
        return false;
    }
    
    self.file = filename;
    self.strings = [NSDictionary dictionaryWithContentsOfFile:strings_path];
    
    return true;
}

- (BOOL)changeLanguage: (NSString *)lang {
    NSString *oldLang = self.language;
    self.language = lang;
    
    if([self loadStringFile: _file]){
        NSLog(@"Localizer Error: Unable to create dictionary for file %@", _file);
        
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
        NSLog(@"Localizer Warning: Couldn't find string for key %@", key);
        return nil;
    }
}

+ (NSString *)stringWithKey:(NSString *)key {
    return [[Localizer instance] stringWithKey:key];
}

- (UIImage *) imageWithName:(NSString *)name {
    return [self imageWithName:name imageNumber:-1];
}

- (UIImage *) imageWithName:(NSString *)name imageNumber:(NSUInteger)imageNumber {
    // Save path extension
    NSString *extension = [name pathExtension];
    // Remove path extension
    name = [name stringByDeletingPathExtension];
    NSString *imageText = @"";
    if (imageNumber > -1) {
        imageText = [NSString stringWithFormat:@"%lu_", (unsigned long)imageNumber];
    }
    NSString *localizedName = [NSString stringWithFormat:@"%@_%@%@.%@", name, imageText, self.language, extension];
    UIImage *image = [UIImage imageNamed:localizedName];
    
    if (!image) {
        localizedName = [NSString stringWithFormat:@"%@%@.%@", name, imageText, extension];
        image = [UIImage imageNamed:localizedName];
        if (!image) {
            NSLog(@"Localizer Warning: Couldn't find any image named %@", localizedName);
        } else if (![self.language isEqualToString:@"en"]) {
            NSLog(@"Localizer Warning: Couldn't find image named %@ using default english image", localizedName);
        }
    }
    
    return image;
}

// Returns a localized image array suitable for passing to an animate function
- (NSArray *) imageAnimationArrayWithName:(NSString *)name numberOfImages:(NSUInteger)numberOfImages {
    NSMutableArray *imageArray = [NSMutableArray new];
    for (unsigned int i = 0; i < numberOfImages; i++) {
        [self imageWithName:name imageNumber:i];
    }
    return imageArray;
}

+ (NSArray *) imageAnimationArrayWithName:(NSString *)name numberOfImages:(NSUInteger)numberOfImages {
    return [[Localizer instance] imageAnimationArrayWithName:name numberOfImages:numberOfImages];
}

+ (UIImage *) imageWithName: (NSString *)name {
    return [[Localizer instance] imageWithName:name];
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
