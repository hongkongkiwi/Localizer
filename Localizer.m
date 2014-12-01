//
//  Localizer.m
//
//  Created by Andy Savage <andy@savage.hk>
//  Copyright (c) 2013 Andy Savage. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreText/CoreText.h>

#import "Localizer.h"
#import "FDSFontDownloader.h"
#import "NSLocale+ISO639_2.h"

#ifndef SUPPORTED_LANGUAGES
#define SUPPORTED_LANGUAGES @[@"en", @"de", @"jp", @"zh_cn", @"it"]
#endif

@interface Localizer() <FDSFontDownloaderDelegate>
@property (nonatomic, strong) FDSFontDownloader *fontDownloader;
@property (nonatomic, assign) bool shouldDownloadSystemFonts;

@end

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
        [self initIOS7Fonts];
        self.fontDownloader = [[FDSFontDownloader alloc] init];
        self.fontDownloader.delegate = self;
        self.shouldDownloadSystemFonts = YES;
        
        self.separator = DEFAULT_SEPARATOR;
        self.removeAtTwoTimes = YES;
        self.logging = YES;
        
        // Check supported languages
        for (NSString *language in SUPPORTED_LANGUAGES) {
            NSString *fileName = [NSString stringWithFormat:@"strings_%@", language];
            NSString* filePath = [[NSBundle mainBundle] pathForResource:fileName ofType:@"txt"];
            NSAssert(filePath, @"Localizer: ERROR - cannot file %@ for language %@", fileName, language);
        }
        
        // Load langauge if it's saved in the prefs
        self.language = [[NSUserDefaults standardUserDefaults] valueForKey: APP_LANG_KEY];
        
        if (self.language == nil) {
            NSString *systemLanguage = [[NSLocale preferredLanguages] objectAtIndex:0];
            NSLocale *systemLocale = [NSLocale localeWithLocaleIdentifier:systemLanguage];
            NSString *iso639 = [systemLocale ISO639_2LanguageIdentifier];
            
            if (self.logging) {
                NSLog(@"Localizer: Device language %@", iso639);
            }
            
            // This is just a quick hack, really we should be using the real letter codes not the ISO639 ones. If we add more langauges (like Traditional Chinese I will look at changing it)
            if ([iso639 isEqualToString:@"zh"]) {
                iso639 = @"zh_cn";
            }
            
            // Set default language to en if preferred language is not supported
            if(![SUPPORTED_LANGUAGES containsObject:iso639]) {
                iso639 = @"en";
            }

            // Set as system language
            self.language = iso639;
        }
    }
    return self;
}

- (void) setLanguage:(NSString *)language {
    [self setLanguage:language save:YES];
}

- (void) setLanguage:(NSString *)language save:(bool)save {
    // Remap
    
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
    
    [self sendReloadLanguageBroadcast];
}

- (void) sendReloadLanguageBroadcast {
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
            ![[NSFileManager defaultManager] fileExistsAtPath:[[NSBundle mainBundle] pathForResource:fontName ofType:@"ttf"]] &&
            ![UIFont fontWithName:fontName size:12]) {
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
        return [UIFont boldSystemFontOfSize:12];
    }

    NSString *fontName = self.fonts[key][@"Name"];
    
    NSString *deviceKey = [self isDeviceIpad] ? @"iPad" : @"iPhone";
    
    CGFloat fontSize = 84;
    if (self.fonts[key][@"Size"][deviceKey]) {
        fontSize = [self.fonts[key][@"Size"][deviceKey] floatValue];
    }
    
    UIFont *font;
    if (!fontName || [fontName length] == 0) {
        if (!self.fonts[key] && self.logging) {
            NSLog(@"Localizer: WARNING - FontName doesn't exist using system font");
        }
        
        font = [UIFont boldSystemFontOfSize:fontSize];
    } else {
        font = [UIFont fontWithName:fontName size:fontSize];
    }
    
    if (!font && self.shouldDownloadSystemFonts) {
        if (self.logging) {
            NSLog(@"Localizer: Font doesn't exist but is in our downloadable dictionary, attempting to download");
        }
        if ([self.downloadableSystemFonts containsObject:[fontName stringByReplacingOccurrencesOfString:@"-" withString:@" "]]) {
            [self asynchronouslySetFontName:fontName];
            return [UIFont boldSystemFontOfSize:fontSize];
        }
    } else if (!font) {
//        [self loadFontFromFile:[[NSBundle mainBundle] pathForResource:@"Yuanti-SC-Bold-stub" ofType:@"ttf"]];
//        font = [UIFont fontWithName:fontName size:fontSize];
//        if (!font) {
            NSLog(@"Localizer: ERROR Font not available %@", fontName);
            return [UIFont boldSystemFontOfSize:fontSize];
//        }
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

#pragma mark - Font Methods
+ (void)downloadableSystemFonts
{
    NSDictionary *attributes = @{(id)kCTFontDownloadableAttribute : (id)kCFBooleanTrue};
    CTFontDescriptorRef fontDescriptor = CTFontDescriptorCreateWithAttributes((CFDictionaryRef)attributes);
    CFArrayRef matchedFontDescriptors = CTFontDescriptorCreateMatchingFontDescriptors(fontDescriptor, NULL);
    
    NSMutableDictionary *familyNames = [[NSMutableDictionary alloc] init];
    NSInteger numberOfFonts = 0;
    NSMutableString *text = [[NSMutableString alloc] init];
    for (UIFontDescriptor *fontDescriptor in (__bridge NSArray *)matchedFontDescriptors) {
        NSString *familyName = fontDescriptor.fontAttributes[UIFontDescriptorFamilyAttribute];
        NSString *displayName = fontDescriptor.fontAttributes[UIFontDescriptorVisibleNameAttribute];
        NSString *postscriptName = fontDescriptor.postscriptName;
        
        if (!familyNames[familyName]) {
            familyNames[familyName] = familyName;
            [text appendFormat:@"<b>%@</b>\n\n", familyName];
        }
        NSMutableDictionary *fontDict = [NSMutableDictionary dictionary];
        fontDict[@"displayName"] = displayName;
        fontDict[@"postscriptName"] = postscriptName;
        fontDict[@"descriptor"] = fontDescriptor;
        NSArray *languages = fontDescriptor.fontAttributes[@"NSCTFontDesignLanguagesAttribute"];
        fontDict[@"languages"] = [languages componentsJoinedByString:@", "];
        
        [text appendFormat:@"- %@ \"%@\" [%@]\n", postscriptName, displayName, [languages componentsJoinedByString:@", "]];
        
        numberOfFonts++;
    }
    
    NSLog(@"%@", text);
}

- (void)asynchronouslySetFontName:(NSString *)fontName
{
	UIFont* aFont = [UIFont fontWithName:fontName size:12.];
    // If the font is already downloaded
	if (aFont && ([aFont.fontName compare:fontName] == NSOrderedSame || [aFont.familyName compare:fontName] == NSOrderedSame)) {
        // Go ahead and display the sample text.
		return;
	}
	
    // Create a dictionary with the font's PostScript name.
	NSMutableDictionary *attrs = [NSMutableDictionary dictionaryWithObjectsAndKeys:fontName, kCTFontNameAttribute, nil];
    
    // Create a new font descriptor reference from the attributes dictionary.
	CTFontDescriptorRef desc = CTFontDescriptorCreateWithAttributes((__bridge CFDictionaryRef)attrs);
    
    NSMutableArray *descs = [NSMutableArray arrayWithCapacity:0];
    [descs addObject:(__bridge id)desc];
    CFRelease(desc);
    
	__block BOOL errorDuringDownload = NO;
	
	// Start processing the font descriptor..
    // This function returns immediately, but can potentially take long time to process.
    // The progress is notified via the callback block of CTFontDescriptorProgressHandler type.
    // See CTFontDescriptor.h for the list of progress states and keys for progressParameter dictionary.
    CTFontDescriptorMatchFontDescriptorsWithProgressHandler( (__bridge CFArrayRef)descs, NULL,  ^(CTFontDescriptorMatchingState state, CFDictionaryRef progressParameter) {
        
		//NSLog( @"state %d - %@", state, progressParameter);
		
		double progressValue = [[(__bridge NSDictionary *)progressParameter objectForKey:(id)kCTFontDescriptorMatchingPercentage] doubleValue];
		
		if (state == kCTFontDescriptorMatchingDidBegin) {
			dispatch_async( dispatch_get_main_queue(), ^ {
                // Show an activity indicator
                // TODO: activity indicator
                
                // Show something in the text view to indicate that we are downloading
				
				NSLog(@"Begin Matching");
			});
		} else if (state == kCTFontDescriptorMatchingDidFinish) {
			dispatch_async( dispatch_get_main_queue(), ^ {
                // Remove the activity indicator
                // TODO: finished download
				
                // Log the font URL in the console
				CTFontRef fontRef = CTFontCreateWithName((__bridge CFStringRef)fontName, 0., NULL);
                CFStringRef fontURL = CTFontCopyAttribute(fontRef, kCTFontURLAttribute);
				NSLog(@"%@", (__bridge NSURL*)(fontURL));
                CFRelease(fontURL);
				CFRelease(fontRef);
                
				if (!errorDuringDownload) {
					NSLog(@"%@ downloaded", fontName);
				}
			});
		} else if (state == kCTFontDescriptorMatchingWillBeginDownloading) {
			dispatch_async( dispatch_get_main_queue(), ^ {
                // Show a progress bar
				// TODO: Empty progress
				NSLog(@"Begin Downloading");
			});
		} else if (state == kCTFontDescriptorMatchingDidFinishDownloading) {
			dispatch_async( dispatch_get_main_queue(), ^ {
                // Remove the progress bar
				// TODO: Finished progress
				NSLog(@"Finish downloading");
                [self sendReloadLanguageBroadcast];
			});
		} else if (state == kCTFontDescriptorMatchingDownloading) {
			dispatch_async( dispatch_get_main_queue(), ^ {
                // Use the progress bar to indicate the progress of the downloading
                // TODO: Upodate progress
				//[_fProgressView setProgress:progressValue / 100.0 animated:YES];
				NSLog(@"Downloading %.0f%% complete", progressValue);
			});
		} else if (state == kCTFontDescriptorMatchingDidFailWithError) {
            // An error has occurred.
            // Get the error message
            NSError *error = [(__bridge NSDictionary *)progressParameter objectForKey:(id)kCTFontDescriptorMatchingError];
            if (error != nil) {
                self.fontDownloadError = [error description];
            } else {
                self.fontDownloadError = @"ERROR MESSAGE IS NOT AVAILABLE!";
            }
            // Set our flag
            errorDuringDownload = YES;
            
            dispatch_async( dispatch_get_main_queue(), ^ {
                // TODO: download error
				NSLog(@"Download error: %@", self.fontDownloadError);
			});
		}
        
		return (bool)YES;
	});
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

- (void) initIOS7Fonts {
    _downloadableSystemFonts = [NSArray arrayWithObjects:@"Al Bayan Bold", @"Al Bayan Plain", @"Al Tarikh", @"Al-Firat", @"Al-Khalil", @"Al-Khalil Bold", @"Al-Rafidain", @"Al-Rafidain Al-Fanni", @"Algiers", @"Andale Mono", @"Apple Braille", @"Apple Braille Outline 6 Dot", @"Apple Braille Outline 8 Dot", @"Apple Braille Pinpoint 6 Dot", @"Apple Braille Pinpoint 8 Dot", @"Apple Chancery", @"Apple LiGothic Medium", @"Apple LiSung Light", @"Apple SD Gothic Neo Bold", @"Apple SD Gothic Neo Heavy", @"Apple SD Gothic Neo Light", @"Apple SD Gothic Neo Medium", @"Apple SD Gothic Neo Regular", @"Apple SD Gothic Neo SemiBold", @"Apple SD Gothic Neo Thin", @"Apple SD Gothic Neo UltraLight", @"Apple SD GothicNeo ExtraBold", @"Apple Symbols", @"AppleGothic Regular", @"AppleMyungjo Regular", @"Arial", @"Arial Black", @"Arial Bold", @"Arial Bold Italic", @"Arial Italic", @"Arial Narrow", @"Arial Narrow Bold", @"Arial Narrow Bold Italic", @"Arial Narrow Italic", @"Arial Unicode MS", @"Ayuthaya", @"Baghdad", @"Bangla MN", @"Bangla MN Bold", @"Baoli SC Regular", @"Basra", @"Basra Bold", @"Beirut", @"BiauKai", @"Big Caslon Medium", @"Book Antiqua", @"Book Antiqua Bold", @"Book Antiqua Bold Italic", @"Book Antiqua Italic", @"Bookman Old Style", @"Bookman Old Style Bold", @"Bookman Old Style Bold Italic", @"Bookman Old Style Italic", @"Brush Script MT Italic", @"Century Gothic", @"Century Gothic Bold", @"Century Gothic Bold Italic", @"Century Gothic Italic", @"Century Schoolbook", @"Century Schoolbook Bold", @"Century Schoolbook Bold Italic", @"Century Schoolbook Italic", @"Chalkboard", @"Chalkboard Bold", @"Comic Sans MS", @"Comic Sans MS Bold", @"Corsiva Hebrew", @"Corsiva Hebrew Bold", @"DecoType Naskh", @"Devanagari MT", @"Devanagari MT Bold", @"Dijla", @"Diwan Kufi", @"Diwan Thuluth", @"Farisi", @"Garamond", @"Garamond Bold", @"Garamond Bold Italic", @"Garamond Italic", @"Gujarati MT", @"Gujarati MT Bold", @"GungSeo Regular", @"Gurmukhi MN", @"Gurmukhi MN Bold", @"Gurmukhi MT", @"Gurmukhi Sangam MN", @"Gurmukhi Sangam MN Bold", @"Hannotate SC Bold", @"Hannotate SC Regular", @"Hannotate TC Bold", @"Hannotate TC Regular", @"HanziPen SC Bold", @"HanziPen SC Regular", @"HanziPen TC Bold", @"HanziPen TC Regular", @"HeadLineA Regular", @"Hei Regular", @"Herculanum", @"Hiragino Kaku Gothic Pro W3", @"Hiragino Kaku Gothic Pro W6", @"Hiragino Kaku Gothic Std W8", @"Hiragino Kaku Gothic StdN W8", @"Hiragino Maru Gothic Pro W4", @"Hiragino Maru Gothic ProN W4", @"Hiragino Mincho Pro W3", @"Hiragino Mincho Pro W6", @"Hiragino Sans GB W3", @"Hiragino Sans GB W6", @"Hoefler Text Ornaments", @"Impact", @"InaiMathi", @"Iowan Old Style Black", @"Iowan Old Style Black Italic", @"Iowan Old Style Bold", @"Iowan Old Style Bold Italic", @"Iowan Old Style Italic", @"Iowan Old Style Roman", @"Iowan Old Style Titling", @"Kai Regular", @"Kaiti SC Black", @"Kaiti SC Bold", @"Kaiti SC Regular", @"Kaiti TC Bold", @"Kaiti TC Regular", @"Kannada MN", @"Kannada MN Bold", @"Kefa Bold", @"Kefa Regular", @"Khmer MN", @"Khmer MN Bold", @"Khmer Sangam MN", @"Kokonor Regular", @"Koufi Abjadi", @"Krungthep", @"KufiStandardGK", @"Laimoon", @"Lantinghei SC Demibold", @"Lantinghei SC Extralight", @"Lantinghei SC Heavy", @"Lantinghei TC Demibold", @"Lantinghei TC Extralight", @"Lantinghei TC Heavy", @"Lao MN", @"Lao MN Bold", @"Lao Sangam MN", @"LiHei Pro", @"LiSong Pro", @"Libian SC Regular", @"Lucida Grande", @"Lucida Grande Bold", @"Malayalam MN", @"Malayalam MN Bold", @"Microsoft Sans Serif", @"Mshtakan", @"Mshtakan Bold", @"Mshtakan BoldOblique", @"Mshtakan Oblique", @"Muna", @"Muna Black", @"Muna Bold", @"Myanmar MN", @"Myanmar MN Bold", @"Myanmar Sangam MN", @"Nadeem", @"Nanum Brush Script", @"Nanum Pen Script", @"NanumGothic", @"NanumGothic Bold", @"NanumGothic ExtraBold", @"NanumMyeongjo", @"NanumMyeongjo Bold", @"NanumMyeongjo ExtraBold", @"New Peninim MT", @"New Peninim MT Bold", @"New Peninim MT Bold Inclined", @"New Peninim MT Inclined", @"Nisan", @"Oriya MN", @"Oriya MN Bold", @"Osaka", @"Osaka-Mono", @"PCMyungjo Regular", @"PT Sans", @"PT Sans Bold", @"PT Sans Bold Italic", @"PT Sans Caption", @"PT Sans Caption Bold", @"PT Sans Italic", @"PT Sans Narrow", @"PT Sans Narrow Bold", @"PilGi Regular", @"Plantagenet Cherokee", @"Raanana", @"Raanana Bold", @"Raya", @"STFangsong", @"STHeiti", @"STIXGeneral-Bold", @"STIXGeneral-BoldItalic", @"STIXGeneral-Italic", @"STIXGeneral-Regular", @"STIXIntegralsD-Bold", @"STIXIntegralsD-Regular", @"STIXIntegralsSm-Bold", @"STIXIntegralsSm-Regular", @"STIXIntegralsUp-Bold", @"STIXIntegralsUp-Regular", @"STIXIntegralsUpD-Bold", @"STIXIntegralsUpD-Regular", @"STIXIntegralsUpSm-Bold", @"STIXIntegralsUpSm-Regular", @"STIXNonUnicode-Bold", @"STIXNonUnicode-BoldItalic", @"STIXNonUnicode-Italic", @"STIXNonUnicode-Regular", @"STIXSizeFiveSym-Regular", @"STIXSizeFourSym-Bold", @"STIXSizeFourSym-Regular", @"STIXSizeOneSym-Bold", @"STIXSizeOneSym-Regular", @"STIXSizeThreeSym-Bold", @"STIXSizeThreeSym-Regular", @"STIXSizeTwoSym-Bold", @"STIXSizeTwoSym-Regular", @"STIXVariants-Bold", @"STIXVariants-Regular", @"STXihei", @"Sana", @"Sathu", @"Savoye LET Plain CC.", @"Savoye LET Plain", @"Silom", @"Sinhala MN", @"Sinhala MN Bold", @"Somer", @"Songti SC Black", @"Songti SC Bold", @"Songti SC Light", @"Songti SC Regular", @"Songti TC Bold", @"Songti TC Light", @"Songti TC Regular", @"Tahoma", @"Tahoma Negreta", @"Tamil MN", @"Tamil MN Bold", @"Telugu MN", @"Telugu MN Bold", @"Tw Cen MT", @"Tw Cen MT Bold", @"Tw Cen MT Bold Italic", @"Tw Cen MT Italic", @"Waseem", @"Waseem Light", @"Wawati SC Regular", @"Wawati TC Regular", @"Webdings", @"Weibei SC Bold", @"Weibei TC Bold", @"Wingdings", @"Wingdings 2", @"Wingdings 3", @"Xingkai SC Bold", @"Xingkai SC Light", @"Yaziji", @"YuGothic Bold", @"YuGothic Medium", @"YuMincho Demibold", @"YuMincho Medium", @"Yuanti SC Bold", @"Yuanti SC Light", @"Yuanti SC Regular", @"Yuppy SC Regular", @"Yuppy TC Regular", @"Zawra Bold", @"Zawra Heavy", nil];
}

#pragma mark - FDSFontDownloader Delegate
- (void)fontDownloadDidBegin {
    NSLog(@"Localizer: Font Download Started");
}

- (void)fontDownloadProgress:(float)progress forFont:(NSString *)fontName {
    if (self.logging) {
        NSLog(@"Localizer: Font Download %@ Progress: %f", fontName, progress);
    }
}

- (void)fontDownloadFinishedDownloadingFontNamed:(NSString *)fontName {
    NSLog(@"Localizer: Font Download Finished for %@", fontName);
    [self sendReloadLanguageBroadcast];
}

- (void)downloadFailedForFont:(NSString *)fontName error:(NSError *)error {
    NSLog(@"Localizer: Font Download Failed for %@ %@", fontName, error);
}

@end
