// 
//  SBADataArchive.m
//  BridgeAppSDK
// 
// Copyright (c) 2015, Apple Inc. All rights reserved. 
// Copyright © 2016 Sage Bionetworks. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//
// 1.  Redistributions of source code must retain the above copyright notice, this
// list of conditions and the following disclaimer.
//
// 2.  Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation and/or
// other materials provided with the distribution.
//
// 3.  Neither the name of the copyright holder(s) nor the names of any contributors
// may be used to endorse or promote products derived from this software without
// specific prior written permission. No license is granted to the trademarks of
// the copyright holders even if such marks are included in this software.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
#import "SBADataArchive.h"
#import <BridgeSDK/BridgeSDK.h>
#import <objc/runtime.h>
#import <ZipZap/ZipZap.h>
#import "SBALog.h"
#import "SBAEncryption.h"
@import ResearchKit;

static NSString * kFileInfoNameKey                  = @"filename";
static NSString * kUnencryptedArchiveFilename       = @"unencrypted.zip";
static NSString * kFileInfoTimeStampKey             = @"timestamp";
static NSString * kFileInfoContentTypeKey           = @"contentType";
static NSString * kTaskRunKey                       = @"taskRun";
static NSString * kFilesKey                         = @"files";
static NSString * kAppNameKey                       = @"appName";
static NSString * kAppVersionKey                    = @"appVersion";
static NSString * kPhoneInfoKey                     = @"phoneInfo";
static NSString * kItemKey                          = @"item";
static NSString * kJsonPathExtension                = @"json";
static NSString * kJsonInfoFilename                 = @"info.json";

@interface SBADataArchive ()

@property (nonatomic, strong) NSString *reference;
@property (nonatomic, strong) ZZArchive *zipArchive;
@property (nonatomic, strong) NSMutableArray *zipEntries;
@property (nonatomic, strong) NSMutableArray *filesList;
@property (nonatomic, strong) NSMutableDictionary *infoDict;
@property (nonatomic, strong) NSMutableArray *expectedJsonFilenames;

@end

@implementation SBADataArchive

- (instancetype)init {
    @throw [NSException exceptionWithName: NSInternalInconsistencyException
                                   reason: @"method unavailable"
                                 userInfo: nil];
    return nil;
}

//designated initializer
- (instancetype)initWithReference:(NSString *)reference
            jsonValidationMapping:(nullable NSDictionary <NSString *, NSPredicate *> *)jsonValidationMapping {
    self = [super init];
    if (self) {
        _reference = [reference copy];
        _jsonValidationMapping = [jsonValidationMapping copy];
        _expectedJsonFilenames = [[jsonValidationMapping allKeys] mutableCopy];
        [self commonInit];
    }
    
    return self;
}

//create a new zip archive at the reference path
- (void)commonInit
{
    NSURL *zipArchiveURL = [NSURL fileURLWithPath:[[self workingDirectoryPath] stringByAppendingPathComponent:kUnencryptedArchiveFilename]];
    _unencryptedURL = zipArchiveURL;

    _zipEntries = [NSMutableArray array];
    _filesList = [NSMutableArray array];
    _infoDict = [NSMutableDictionary dictionary];
    NSError * error;
    
    _zipArchive = [[ZZArchive alloc] initWithURL:zipArchiveURL
                                             options:@{ZZOpenOptionsCreateIfMissingKey : @YES}
                                               error:&error];
    if (!_zipArchive) {
        SBALogError2(error);
        NSAssert(NO, @"Failed to create zip archive");
    }
}

//A sandbox in the temporary directory for this archive to be cleaned up on completion.
- (NSString *)workingDirectoryPath
{
    
    NSString *workingDirectoryPath = [NSTemporaryDirectory() stringByAppendingPathComponent:self.reference];
    if (![[NSFileManager defaultManager] fileExistsAtPath:workingDirectoryPath]) {
        NSError * fileError;
        BOOL created = [[NSFileManager defaultManager] createDirectoryAtPath:workingDirectoryPath withIntermediateDirectories:YES attributes:@{ NSFileProtectionKey : NSFileProtectionComplete } error:&fileError];
        if (!created) {
            workingDirectoryPath = nil;
            SBALogError2(fileError);
            NSAssert(NO, @"Failed to create working directory");
        }
    }
    
    return workingDirectoryPath;
}

- (void)setArchiveInfoObject:(id <SBAJSONObject>)object forKey:(NSString*)key {
    self.infoDict[key] = [object jsonObjectWithFormatter:nil];
}

- (void)insertURLIntoArchive:(NSURL*)url fileName:(NSString *)filename
{
    NSData *dataToInsert = [NSData dataWithContentsOfURL:url];
    [self insertDataIntoArchive:dataToInsert filename:filename];
}

- (void)insertDictionaryIntoArchive:(NSDictionary *)dictionary filename:(NSString *)filename
{
    SBALogDebug(@"Archiving %@: %@", filename, dictionary);
    
    NSPredicate *validationPredicate = self.jsonValidationMapping[filename];
    if (validationPredicate && ![validationPredicate evaluateWithObject:dictionary]) {
        NSError *error = [NSError errorWithDomain:NSStringFromClass([self class]) code:1
                                         userInfo:@{ @"filename": filename,
                                                     @"json": dictionary,
                                                     @"validationPredicate": validationPredicate}];
        SBALogError2(error);
        NSAssert1(false, @"%@", error);
    }
    [self.expectedJsonFilenames removeObject:filename];
    
    NSError * serializationError;
    NSData * jsonData = [NSJSONSerialization dataWithJSONObject:dictionary options:NSJSONWritingPrettyPrinted error:&serializationError];
        
    if (jsonData != nil) {
        [self insertDataIntoArchive:jsonData filename:filename];
    }
    else {
        SBALogError2(serializationError);
        NSAssert(NO, @"Failed to serialize JSON dictionary");
    }
}

- (void)insertDataIntoArchive :(NSData *)data filename: (NSString *)filename
{
    // Check that the file has not already been added
    if ([self.filesList filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"%K = %@", kFileInfoNameKey, filename]].count != 0) {
        NSAssert1(NO, @"File has already been added: %@", filename);
        return;
    }
    
    [self.zipEntries addObject: [ZZArchiveEntry archiveEntryWithFileName: filename
                                                                compress:YES
                                                               dataBlock:^(NSError** error)
                                 {
                                     SBALogError2(*error);
                                     return data;
                                 }]];
    
    //add the fileInfoEntry
    NSString *extension = [filename pathExtension] ? : kJsonPathExtension;
    NSDictionary *fileInfoEntry = @{ kFileInfoNameKey: filename,
                                     kFileInfoTimeStampKey: [[NSDate date] jsonObjectWithFormatter:nil],
                                     kFileInfoContentTypeKey: [self contentTypeForFileExtension:extension] };
    
    [self.filesList addObject:fileInfoEntry];

}

+ (NSString *)appVersion
{
    static NSString *appVersion = nil;
    if (!appVersion)
    {
        NSString *version = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        NSString *build   = NSBundle.mainBundle.appVersion;
        appVersion	= [NSString stringWithFormat: @"version %@, build %@", version, build];
    }
    
    return appVersion;
}

- (BOOL)isEmpty
{
    return self.filesList.count == 0;
}

//Compiles the final info.json file and inserts it into the zip archive.
- (BOOL)completeArchive:(NSError **)error
{
    BOOL success = YES;
    NSError *internalError = nil;
    if (!self.isEmpty) {
        
        if (self.expectedJsonFilenames.count > 0) {
            NSString *filenames = [self.expectedJsonFilenames componentsJoinedByString:@","];
            NSError *validationError = [NSError errorWithDomain:NSStringFromClass([self class]) code:1
                                             userInfo:@{ @"message": [NSString stringWithFormat:@"Missing expected json files: %@", filenames]
                                                         }];
            SBALogError2(validationError);
            NSAssert1(false, @"%@", validationError);
            if (error) {
                *error = validationError;
                return NO;
            }
        }
        
        [self.infoDict setObject:self.filesList forKey:kFilesKey];
        
        [self.infoDict setObject:self.reference forKey:kItemKey];
        [self.infoDict setObject:[[NSBundle mainBundle] appName] forKey:kAppNameKey];
        [self.infoDict setObject:[self.class appVersion] forKey:kAppVersionKey];
        [self.infoDict setObject:[[UIDevice currentDevice] deviceInfo] forKey:kPhoneInfoKey];

        [self insertDictionaryIntoArchive:self.infoDict filename:kJsonInfoFilename];
        
        if (![self.zipArchive updateEntries:self.zipEntries error:&internalError]) {
            SBALogError2(internalError);
            success = NO;
            if (error) {
                *error = internalError;
            }
        }
    }
    
    return success;
}

- (void)encryptAndUploadArchive
{
    SBAEncryption *encryptor = [SBAEncryption new];
    
    [encryptor encryptFileAtURL:_unencryptedURL withCompletion:^(NSURL *url, NSError *error) {
        if (!error) {
            //remove the archive after encryption
            [self removeArchive];
            
            //upload the encrypted archive
            [SBBComponent(SBBUploadManager) uploadFileToBridge:url contentType:@"application/zip" completion:^(NSError *error) {
                if (!error) {
                    SBALogEventWithData(@"NetworkEvent", (@{@"event_detail":[NSString stringWithFormat:@"SBADataArchive uploaded file: %@", url.relativePath.lastPathComponent]}));
                    [encryptor removeDirectory];
                    // TODO: emm 2016-05-18 Fire off a delayed validation check and output the response
                } else {
                    SBALogDebug(@"SBADataArchive error returned from SBBUploadManager:\n%@\n%@", error.localizedDescription, error.localizedFailureReason);
                }

            }];
        }
    }];
}

+ (void)encryptAndUploadArchives:(NSArray<SBADataArchive *> *)archives
{
    for (SBADataArchive *archive in archives) {
        [archive encryptAndUploadArchive];
    }
}

//delete the workingDirectoryPath, and therefore its contents.
-(void)removeArchive
{
    NSError *err;
    if (![[NSFileManager defaultManager] removeItemAtPath:[self workingDirectoryPath] error:&err]) {
        NSAssert(false, @"failed to remove unencrypted archive at %@",[self workingDirectoryPath] );
        SBALogError2(err);
    }
}

#pragma mark - Helpers

- (NSString *)contentTypeForFileExtension: (NSString *)extension
{
    NSString *contentType;
    if ([extension isEqualToString:@"csv"]) {
        contentType = @"text/csv";
    }else if ([extension isEqualToString:@"m4a"]) {
        contentType = @"audio/mp4";
    }else {
        contentType = @"application/json";
    }
    
    return contentType;
}

@end
