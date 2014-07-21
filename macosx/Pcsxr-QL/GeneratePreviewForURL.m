#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>
#include "MyQuickLook.h"
//#include <zlib.h>
#import <Cocoa/Cocoa.h>
//#include "nopic.h"
#import "PSXMemEnumerator.h"

/* -----------------------------------------------------------------------------
   Generate a preview for file

   This function's job is to create preview for designated file
   ----------------------------------------------------------------------------- */

static OSStatus GeneratePreviewForFreeze(void *thisInterface, QLPreviewRequestRef preview, NSURL *url, NSDictionary *options);
static OSStatus GeneratePreviewForMemCard(void *thisInterface, QLPreviewRequestRef preview, NSURL *url, NSDictionary *options);

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options)
{
	OSStatus theStatus = noErr;
	@autoreleasepool {
		NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
		NSURL *urlNS = (__bridge NSURL*)url;
		NSString *uti = (__bridge NSString*)contentTypeUTI;
		NSDictionary *optionsNS = (__bridge NSDictionary*)options;
		if ([workspace type:uti conformsToType:@"com.codeplex.pcsxr.freeze"]) {
			theStatus = GeneratePreviewForFreeze(thisInterface, preview, urlNS, optionsNS);
		} else if ([workspace type:uti conformsToType:@"com.codeplex.pcsxr.memcard"]) {
			theStatus = GeneratePreviewForMemCard(thisInterface, preview, urlNS, optionsNS);
		}
	}
	return theStatus;
}

void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview)
{
	// Implement only if supported
}

OSStatus GeneratePreviewForFreeze(void *thisInterface, QLPreviewRequestRef preview, NSURL *url, NSDictionary *options)
{
#if 0
	NSData *data;
	gzFile f;
	const char* state_filename;
	if ([url respondsToSelector:@selector(fileSystemRepresentation)]) {
		state_filename = [url fileSystemRepresentation];
	} else {
		state_filename = [[url path] fileSystemRepresentation];
	}
	
	if (!state_filename) {
		return fnfErr;
	}
	
	unsigned char *pMem = (unsigned char *) malloc(128*96*3);
	if (pMem == NULL)
		return mFulErr;
	
	f = gzopen(state_filename, "rb");
	if (f != NULL) {
		gzseek(f, 32, SEEK_SET); // skip header
		gzseek(f, sizeof(uint32_t), SEEK_CUR);
		gzseek(f, sizeof(uint8_t), SEEK_CUR);
		gzread(f, pMem, 128*96*3);
		gzclose(f);
	} else {
		memcpy(pMem, NoPic_Image.pixel_data, 128*96*3);
	}
	
	NSBitmapImageRep *imRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:&pMem pixelsWide:NoPic_Image.width pixelsHigh:NoPic_Image.height bitsPerSample:8 samplesPerPixel:3 hasAlpha:NO isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bitmapFormat:0 bytesPerRow:NoPic_Image.width * NoPic_Image.bytes_per_pixel bitsPerPixel:24];
	if (imRep) {
		data = [imRep TIFFRepresentation];
		QLPreviewRequestSetDataRepresentation(preview, (__bridge CFDataRef)(data), kUTTypeImage, NULL);
	}
	free(pMem);
	return noErr;
#else
	return unimpErr;
#endif
}

static OSStatus GeneratePreviewForMemCard(void *thisInterface, QLPreviewRequestRef preview, NSURL *url, NSDictionary *options)
{
	NSArray *memCards = CreateArrayByEnumeratingMemoryCardAtURL(url);
	NSMutableString *htmlStr = [[NSMutableString alloc] initWithCapacity:memCards.count * 200];
	NSMutableDictionary *htmlDict = [[NSMutableDictionary alloc] initWithCapacity:memCards.count];
	int i;
	for (PcsxrMemoryObject *obj in memCards) {
		NSImage *theImage = [obj firstMemImage];
		NSData *tiffData = [theImage TIFFRepresentation];
		NSBitmapImageRep *bmImg = [NSBitmapImageRep imageRepWithData:tiffData];
		NSData *pngData = [bmImg representationUsingType:NSPNGFileType properties:nil];
		NSDictionary *imgProps = @{(NSString *)kQLPreviewPropertyAttachmentDataKey: pngData,
								   (NSString *)kQLPreviewPropertyMIMETypeKey: @"image/png"};
		NSString *imgName = [[@(i++) stringValue] stringByAppendingPathComponent:@"png"];
		[htmlStr appendFormat:@"<tr><td><img src=\"cid:%@\"></td><td>%@</td><td>%i</td></tr>\n", imgName, obj.sjisName, obj.blockSize];
		htmlDict[imgName] = imgProps;
	}
	
	NSString *theStr = [[NSString alloc] initWithFormat:@"<html>\n<body>\n<table>\n<tr><td ALIGN=center>Image</td><td ALIGN=name>Image</td><td ALIGN=center>Count</td></tr>%@\n</table>\n</body>\n</html>", htmlStr];
	
	NSData *data = [theStr dataUsingEncoding:NSUTF8StringEncoding];
	NSDictionary *previewDict =
 @{(NSString *)kQLPreviewPropertyAttachmentsKey: htmlDict,
   (NSString *)kQLPreviewPropertyDisplayNameKey: [url lastPathComponent],
   (NSString *)kQLPreviewPropertyWidthKey: @400,
   (NSString *)kQLPreviewPropertyHeightKey: @400};
	
	QLPreviewRequestSetDataRepresentation(preview, (__bridge CFDataRef)(data), kUTTypeHTML, (__bridge CFDictionaryRef)(previewDict));
	
	return noErr;
}
