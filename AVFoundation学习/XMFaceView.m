//
//  XMFaceView.m
//  AVFoundation学习
//
//  Created by RenXiangDong on 17/1/19.
//  Copyright © 2017年 RenXiangDong. All rights reserved.
//

#import "XMFaceView.h"

@implementation XMFaceView

+ (instancetype)viewWithFrame:(CGRect)frame {
    XMFaceView *view = [[[NSBundle mainBundle] loadNibNamed:@"XMFaceView" owner:self options:nil] lastObject];
    view.frame = frame;
    return view;
}

@end
