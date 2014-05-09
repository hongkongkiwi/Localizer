//
//  Localizer.m
//
//  Created by Andy Savage <andy@savage.hk>
//  Copyright (c) 2013 Andy Savage. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Localizer.h"

#ifndef SUPPORTED_LANGUAGES
#define SUPPORTED_LANGUAGES @[@"en", @"de", @"jp", @"zh_cn"]
#endif

@implementation Localizer

static Localizer *_globalInstance;

+ (Localizer *)instance {
    if(_globalInstance == nil){
        _globalInstance = [[Localizer alloc] init];
    }
    return _globalInstance;
}

- (id)init {
    if (self = [super init]) {
        self.separator = DEFAULT_SEPARATOR;
        self.removeAtTwoTimes = YES;
        self.logging = YES;
        
        // Check supported languages
        for (NSString *language in SUPPORTED_LANGUAGES) {
            NSString *fileName = [NSString stringWithFormat:@"strings_%@", language];
            NSString* filePath = [[NSBundle mainBundle] pathForResource:fileName ofType:@"txt"];
            NSAssert(filePath, @"Localizer: ERROR - cannot file %@ for language %@", fileName, language);
        }
        
        self.language = [[NSUserDefaults standardUserDefaults] valueForKey: APP_LANG_KEY];
        
        if (self.language == nil) {
            NSString *systemLanguage = [[NSLocale preferredLanguages] objectAtIndex:0];
            
            if (self.logging) {
                NSLog(@"Localizer: Device language %@", systemLanguage);
            }

            // Set as system language
            self.language = systemLanguage;
        }
    }
    return self;
}

- (void) setLanguage:(NSString *)language {
    [self setLanguage:language save:YES];
}

- (void) setLanguage:(NSString *)language save:(bool)save {
    // Check if the language is in our supported languages list
    if ([SUPPORTED_LANGUAGES containsObject:language]) {
        _language = language;
    } else {
        if (self.logging) {
            NSLog(@"Localizer: WARNING - Tried to set language to %@ but we don't support it", language);
        }
        return;
    }

    // Try to load all our language dependant files
    NSDictionary *strings = [self loadFromFile:@"strings"];
    NSDictionary *fonts = [self loadFromFile:@"fonts" ofType:@"json"];
    
    // Check if load was successful
    if (strings && fonts) {
        self.strings = strings;
        self.fonts = fonts;
        [self checkAllFonts:fonts]; // Just do a check to ensure all is good
    } else {
        if (self.logging) {
            NSLog(@"Localizer: ERROR - Cannot load strings & fonts for %@", language);
            return;
        }
    }
    
    if (save) {
        // Save the new language in the user defaults
        [[NSUserDefaults standardUserDefaults] setValue:_language forKey:APP_LANG_KEY];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:LANGUAGE_CHANGED_BROADCASTID object:self];
}

-(NSDictionary *) dictionaryWithContentsOfJSONString:(NSString *)fileLocation {
    NSString *filePath = [[NSBundle mainBundle] pathForResource:[fileLocation stringByDeletingPathExtension] ofType:[fileLocation pathExtension]];
    NSData* data = [NSData dataWithContentsOfFile:filePath];
    __autoreleasing NSError* error = nil;
    if (data == nil) {
        return nil;
    }
    id result = [NSJSONSerialization JSONObjectWithData:data
                                                options:kNilOptions error:&error];
    // Be careful here. You add this as a category to NSDictionary
    // but you get an id back, which means that result
    // might be an NSArray as well!
    if (error != nil) return nil;
    return result;
}

- (NSDictionary *) loadFromFile:(NSString *)filename {
    return [self loadFromFile:filename ofType:@"txt"];
}

- (NSDictionary *) loadFromFile:(NSString *)filename ofType:(NSString *)ofType {
    // Generate the name of the file including the language
    NSString *filenameWithLanguage = [NSString stringWithFormat: @"%@_%@", filename, self.language];
    
    NSString *filePath = [[NSBundle mainBundle] pathForResource:filenameWithLanguage ofType:ofType];
    
    NSString *usedFilename = filenameWithLanguage;
    
    if (!filePath) {
        filePath = [[NSBundle mainBundle] pathForResource:filename ofType:ofType];
        if (!filePath) {
            if (self.logging) {
                NSLog(@"Localizer: ERROR - Unable to get path for file %@", filename);
            }
            return nil;
        }
        usedFilename = filename;
    }
    
    NSDictionary *loadedDict;
    if ([ofType isEqualToString:@"json"]) {
        loadedDict = [self dictionaryWithContentsOfJSONString:[usedFilename stringByAppendingPathExtension:@"json"]];
    } else if ([ofType isEqualToString:@"txt"]) {
        loadedDict = [NSDictionary dictionaryWithContentsOfFile:filePath];
    }
    
    if (!loadedDict) {
        if (self.logging) {
            NSLog(@"Localizer: ERROR - Tried to load invalid file %@", usedFilename);
        }
        return nil;
    }
    
    if ([loadedDict count] == 0) {
        if (self.logging) {
            NSLog(@"Localizer: WARNING - %@ was is loaded but is an empty dictionary", usedFilename);
        }
    }
    
    //return @{@"contents": loadedDict, @"filename": usedFilename};
    return loadedDict;
}

- (bool) isDeviceIpad {
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
}

// This method checks all fonts in the dictionary actually exist in our info.plist
- (void) checkAllFonts:(NSDictionary *)fontsDict {
    NSDictionary* infoDict = [[NSBundle mainBundle] infoDictionary];
    NSArray *fontsIncluded = [infoDict objectForKey:@"UIAppFonts"];
    NSLog(@"Fonts %@", fontsIncluded);
    
    for (NSString *fontDictKey in fontsDict) {
        NSDictionary *fontDict = fontsDict[fontDictKey];
        NSString *fontName = fontDict[@"Name"];
        
        if (![[NSFileManager defaultManager] fileExistsAtPath:[[NSBundle mainBundle] pathForResource:fontName ofType:@"otf"]] &&
            ![[NSFileManager defaultManager] fileExistsAtPath:[[NSBundle mainBundle] pathForResource:fontName ofType:@"ttf"]]) {
            if (self.logging) {
                NSLog(@"Localizer: ERROR - Font %@ was expected but does not exist in application bundle", fontName);
            }
        }
    }
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

+ (UIFont *)fontWithKey:(NSString *)key {
    return [[Localizer instance] fontWithKey:key];
}

- (UIFont *)fontWithKey:(NSString *)key {
    
    if (!self.fonts[key]) {
        if (self.logging) {
            NSLog(@"Localizer: ERROR - Tried to get font with key %@ but it doesn't exist in our dictionary", key);
        }
        // Safe fallback
        return [UIFont systemFontOfSize:12];
    }

    NSString *fontName = self.fonts[key][@"Name"];
    
    NSString *deviceKey = [self isDeviceIpad] ? @"iPad" : @"iPhone";
    
    CGFloat fontSize = 84;
    if (self.fonts[key][@"Size"][deviceKey]) {
        fontSize = [self.fonts[key][@"Size"][deviceKey] floatValue];
    }
    
    UIFont *font;
    if (!fontName) {
        font = [UIFont systemFontOfSize:fontSize];
    } else {
        font = [UIFont fontWithName:fontName size:fontSize];
    }
    
    return font;
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
//            if (self.logging) {
//                NSLog(@"Localizer Warning: Couldn't find image named %@ using default english image", localizedName);
//            }
            localizedName = [NSString stringWithFormat:@"%@%@%@.%@", name, imageText, atTwoTimes, extension];
            image = [UIImage imageNamed:localizedName];
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

- (void) displayAllInstalledFonts {
    for (NSString* family in [UIFont familyNames])
    {
        NSLog(@"%@", family);
        
        for (NSString* name in [UIFont fontNamesForFamilyName: family])
        {
            NSLog(@"  %@", name);
        }
    }
}

@end
