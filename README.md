Localizer for iOS
=================

A simple text and image localisation class for IOS.

We created this to be a little bit more flexible than the inbuilt localiser. It also uses a consistent file format which can be used across the IOS version as well.

Getting Started
===============
Using Localizer is very simple simply clone the repository

```
$ git clone https://github.com/hongkongkiwi/Localizer.git
```

And add Localizer.m and Localizer.h to your iOS project.

It’s as simple as that.

Methods
===============
```+ (Localizer *)instance;```

/** Loads strings from a file in the apple dictionary format **/

```- (BOOL)loadStringFile: (NSString *)filename;```

/** Change the language used in the localizer using a two string lang code **/

```- (BOOL)changeLanguage: (NSString *)lang;```

/** Get a string using a key **/
```- (NSString *)stringWithKey: (NSString *)key;```

```+ (NSString *)stringWithKey: (NSString *)key;```

```- (UIImage *)imageNamed: (NSString *)name;```

```+ (UIImage *)imageNamed: (NSString *)name;```

```- (NSArray *) imageAnimationArrayWithImageNamed:(NSString *)name numberOfImages:(NSUInteger)numberOfImages;```

```+ (NSArray *) imageAnimationArrayWithImageNamed:(NSString *)name numberOfImages:(NSUInteger)numberOfImages;```

/** Checks if a string exists using a key **/

```- (BOOL)objectForKeyExists: (NSString *)key;```

/** Get an array using a key **/

```- (NSArray *)arrayWithKey: (NSString *)key;```

```+ (NSArray *)arrayWithKey: (NSString *)key;```

```- (NSString *)stringWithKey: (NSString *)key atIndex: (int)index;```

/** Helper method to determine if the current language is english **/

```- (BOOL)isEnglish;```

License
=======
Localizer is available under the Apache License, Version 2.0 license. See the LICENSE.txt file for more info.