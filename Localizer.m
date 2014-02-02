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
        NSLog(@"Unable to create dictionary for file %@", _file);
        
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

- (BOOL)objectForKeyExists: (NSString *)key {
    return ([_strings objectForKey:key] != nil);
}

- (NSArray *)arrayWithKey: (NSString *)key {
    NSString *string = [self stringWithKey:key];
    return ([string length] > 0) ? [string componentsSeparatedByString: _separator] : nil;
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
