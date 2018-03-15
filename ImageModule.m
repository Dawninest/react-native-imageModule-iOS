//
//  ImageModule.m
//  moffice
//
//  Created by 30san on 2018/2/11.
//  Copyright © 2018年 Facebook. All rights reserved.
//

#import "ImageModule.h"

#define SCREEN_H [UIScreen mainScreen].bounds.size.height
#define SCREEN_W [UIScreen mainScreen].bounds.size.width
#define H_MAX SCREEN_H * 0.21
#define W_MAX SCREEN_W * 0.36
#define MaxLocal 100

@interface ImageModule ()

@property (nonatomic, strong) NSString *picPath;
@property (nonatomic, strong) NSString *returnPath;

@end

@implementation ImageModule


RCT_EXPORT_MODULE();

RCT_EXPORT_METHOD(createScaledAvatar:(NSString *)picPath
                  smallPath:(NSString *)smallPath
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject){
  //生成本地小头像，width不超过100
  self.picPath = [self getUsePath:picPath];
  self.returnPath = [self getUsePath:smallPath];
  UIImage *oldPic = [UIImage imageWithContentsOfFile:self.picPath];
  CGSize roomSize = [self getPicZoomSize:oldPic];
  UIImage *zoomPic = [self zoomPic:oldPic size:roomSize];
  BOOL compressRes = [self compressPic:zoomPic picQuality:0.618];
  if(compressRes){
    resolve(@"success");
  } else {
    reject(@"fail",NULL,NULL);
  }
}

RCT_EXPORT_METHOD(createLocalImage:(NSString *)picPath
                  localPath:(NSString *)returnPath
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject){
  self.returnPath = [self getUsePath:returnPath];
  self.picPath = [self getUsePath:picPath];
  UIImage *pic = [UIImage imageWithContentsOfFile:self.picPath];
  double sendPicMAX = 1280;
  double sendPicMIN = 420;
  double picWidth = pic.size.width;
  double picHeight = pic.size.height;
  double radio = MIN(picWidth, picHeight)/MAX(picWidth, picHeight);
  int needWidth = 0;
  int needHeight = 0;
  if (MIN(picWidth, picHeight)<sendPicMIN) {
    //无需处理，直接保存
    NSData *picData = UIImageJPEGRepresentation(pic, 0.618);
    [picData writeToFile:self.returnPath options:NSAtomicWrite error:NULL];
  }else{
    if (MAX(picWidth, picHeight)<sendPicMAX) {
      //不改变尺寸,进行图片压缩处理
      CGFloat picQuality = 0.2;
      [self compressPic:pic picQuality:picQuality];
    }else{
      //进行图片缩放处理
      needWidth = picWidth > picHeight ? sendPicMAX : sendPicMAX * radio;
      needHeight = picWidth > picHeight ? sendPicMAX * radio : sendPicMAX;
      UIImage *zoomPic = [self zoomPic:pic size:CGSizeMake(needWidth, needHeight)];
      [self compressPic:zoomPic picQuality:0.618];
    }
  }
  resolve(@"success");
}

RCT_EXPORT_METHOD(createScaledImage:(NSString *)picPath
                  localPath:(NSString *)returnPath
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject){
  //生成本地小头像，width不超过100
  self.returnPath = [self getUsePath:returnPath];
  self.picPath = [self getUsePath:picPath];
  UIImage *pic = [UIImage imageWithContentsOfFile:self.picPath];
  double picWidth = pic.size.width;
  double picHeight = pic.size.height;
  double radio = MIN(picWidth, picHeight)/MAX(picWidth, picHeight);
  int needWidth = 0;
  int needHeight = 0;
  if (radio>0.5) {
    if (picWidth<W_MAX && picHeight<H_MAX) {
      //无需处理，直接保存
      NSData *picData = UIImageJPEGRepresentation(pic, 1.0);
      [picData writeToFile:self.returnPath options:NSAtomicWrite error:NULL];
    }else{
      //图片缩放
      needWidth = picWidth > picHeight ? W_MAX : H_MAX * radio;
      needHeight = picWidth > picHeight ? W_MAX * radio : H_MAX;
      UIImage *zoomPic = [self zoomPic:pic size:CGSizeMake(needWidth, needHeight)];
      [self compressPic:zoomPic picQuality:1.0];
    }
  }else{
    //图片裁剪
    if (picWidth>picHeight) {
      needWidth = picHeight*2 > W_MAX ? H_MAX : picHeight*2;
      needHeight = picHeight*2 > W_MAX ? H_MAX/2 : picHeight;
    }else{
      needWidth = picWidth*2 > H_MAX ? H_MAX/2 : picWidth;
      needHeight = picWidth*2 > H_MAX ? H_MAX : picWidth*2;
    }
    [self cutPic:pic size:CGSizeMake(needWidth, needHeight)];
  }
  resolve(@"success");
}

RCT_EXPORT_METHOD(getScaledWidthHeight:(double)picWidth
                  height:(double)picHeight
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject){
  
  double radio = MIN(picWidth, picHeight)/MAX(picWidth, picHeight);
  int needWidth = 0;
  int needHeight = 0;
  if (radio > 0.5) {
    if (picWidth < W_MAX && picHeight < H_MAX) {
      //无需处理，直接保存
      needWidth = picWidth;
      needHeight = picHeight;
    }else{
      //图片缩放
      needWidth = picWidth > picHeight ? W_MAX : H_MAX * radio;
      needHeight = picWidth > picHeight ? W_MAX * radio : H_MAX;
    }
  }else{
    //图片裁剪
    if (picWidth>picHeight) {
      needWidth = picHeight * 2 > W_MAX ? H_MAX : picHeight*2;
      needHeight = picHeight * 2 > W_MAX ? H_MAX/2 : picHeight;
    }else{
      needWidth = picWidth*2 > H_MAX ? H_MAX/2 : picWidth;
      needHeight = picWidth*2 > H_MAX ? H_MAX : picWidth*2;
    }
  }
  NSMutableDictionary *backSize = [NSMutableDictionary dictionary];
  [backSize setObject:@(needWidth) forKey:@"width"];
  [backSize setObject:@(needHeight) forKey:@"height"];
  resolve(backSize);
}

- (CGSize)getPicZoomSize:(UIImage *)pic {
  // 这里头像全是方形图。
  int picWidth = pic.size.width;
  picWidth = pic.size.width > MaxLocal ? MaxLocal : pic.size.width;
  return CGSizeMake(picWidth, picWidth);
}

/*图片缩放*/
-(UIImage *)zoomPic:(UIImage *)oldPic size:(CGSize)roomSize{
  UIGraphicsBeginImageContext(roomSize);
  [oldPic drawInRect:CGRectMake(0, 0, roomSize.width, roomSize.height)];
  UIImage *newPic = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  return newPic;
}

/*图片压缩*/
-(BOOL)compressPic:(UIImage *)oldPic picQuality:(CGFloat)picQuality{
  NSError* err = nil;
  NSData *picData = UIImageJPEGRepresentation(oldPic, picQuality);
  BOOL compressPicSuccess = [picData writeToFile:self.returnPath options:NSAtomicWrite error:&err];
  return compressPicSuccess;
}

/*长图片的裁剪*/
-(void)cutPic:(UIImage *)oldPic size:(CGSize)roomSize{
  double oldPicWidth = oldPic.size.width;
  double oldPicHeight = oldPic.size.height;
  double needPicWidth = roomSize.width;
  double needPicHeight = roomSize.height;
  CGRect cutRect = CGRectMake((oldPicWidth - needPicWidth)/2, (oldPicHeight - needPicHeight)/2, needPicWidth, needPicHeight);
  CGImageRef cgPic = CGImageCreateWithImageInRect([oldPic CGImage], cutRect);
  UIImage *newPic = [UIImage imageWithCGImage:cgPic];
  CGImageRelease(cgPic);
  [self compressPic:newPic picQuality:1.0];
}
// 去掉头部  file://
- (NSString *)getUsePath:(NSString *)picPath{
  if ([[picPath substringToIndex:7] isEqualToString:@"file://"]) {
    return [picPath substringFromIndex:7];
  } else {
    return picPath;
  }
}

@end
