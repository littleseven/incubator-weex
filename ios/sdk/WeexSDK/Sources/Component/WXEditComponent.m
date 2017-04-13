/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 * 
 *   http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

#import "WXEditComponent.h"
#import "WXConvert.h"
#import "WXUtility.h"
#import "WXSDKInstance.h"
#import "WXSDKInstance_private.h"
#import "WXDefine.h"
#import "WXAssert.h"
#import "WXComponent_internal.h"
#import "WXComponent+PseudoClassManagement.h"

@interface WXEditComponent()

//@property (nonatomic, strong) WXTextInputView *inputView;
@property (nonatomic, strong) WXDatePickerManager *datePickerManager;
@property (nonatomic, strong) NSDictionary *attr;
//attribute
@property (nonatomic) NSNumber *maxLength;
@property (nonatomic) NSString * value;
@property (nonatomic) BOOL autofocus;
@property(nonatomic) UIReturnKeyType returnKeyType;
@property (nonatomic) BOOL disabled;
@property (nonatomic, copy) NSString *inputType;
@property (nonatomic) NSUInteger rows;

//style
@property (nonatomic) WXPixelType fontSize;
@property (nonatomic) WXTextStyle fontStyle;
@property (nonatomic) CGFloat fontWeight;
@property (nonatomic, strong) NSString *fontFamily;
@property (nonatomic, strong) UIColor *colorForStyle;
@property (nonatomic)NSTextAlignment textAlignForStyle;

//event
@property (nonatomic) BOOL inputEvent;
@property (nonatomic) BOOL clickEvent;
@property (nonatomic) BOOL focusEvent;
@property (nonatomic) BOOL blurEvent;
@property (nonatomic) BOOL changeEvent;
@property (nonatomic) BOOL returnEvent;
@property (nonatomic) BOOL keyboardEvent;
@property (nonatomic, strong) NSString *changeEventString;
@property (nonatomic, assign) CGSize keyboardSize;

@end

@implementation WXEditComponent
{
    UIEdgeInsets _border;
    UIEdgeInsets _padding;
}

WX_EXPORT_METHOD(@selector(focus))
WX_EXPORT_METHOD(@selector(blur))
WX_EXPORT_METHOD(@selector(setSelectionRange:selectionEnd:))
WX_EXPORT_METHOD(@selector(getSelectionRange:))

- (instancetype)initWithRef:(NSString *)ref type:(NSString *)type styles:(NSDictionary *)styles attributes:(NSDictionary *)attributes events:(NSArray *)events weexInstance:(WXSDKInstance *)weexInstance
{
    self = [super initWithRef:ref type:type styles:styles attributes:attributes events:events weexInstance:weexInstance];
    if (self) {
        _inputEvent = NO;
        _focusEvent = NO;
        _blurEvent = NO;
        _changeEvent = NO;
        _returnEvent = NO;
        _clickEvent = NO;
        _keyboardEvent = NO;
        // handle attributes
        _autofocus = [attributes[@"autofocus"] boolValue];
        _disabled = [attributes[@"disabled"] boolValue];
        _value = [WXConvert NSString:attributes[@"value"]]?:@"";
        _placeholderString = [WXConvert NSString:attributes[@"placeholder"]]?:@"";
        if(attributes[@"type"]) {
            _inputType = [WXConvert NSString:attributes[@"type"]];
            _attr = attributes;
        }
        if (attributes[@"maxlength"]) {
            _maxLength = [NSNumber numberWithUnsignedInteger:[attributes[@"maxlength"] integerValue]];
        }
        if (attributes[@"returnKeyType"]) {
            _returnKeyType = [WXConvert UIReturnKeyType:attributes[@"returnKeyType"]];
        }
        if (attributes[@"rows"]) {
            _rows = [attributes[@"rows"] integerValue];
        } else {
            _rows = 2;
        }
        
        // handle styles
        if (styles[@"color"]) {
            _colorForStyle = [WXConvert UIColor:styles[@"color"]];
        }
        if (styles[@"fontSize"]) {
            _fontSize = [WXConvert WXPixelType:styles[@"fontSize"] scaleFactor:self.weexInstance.pixelScaleFactor];
        }
        if (styles[@"fontWeight"]) {
            _fontWeight = [WXConvert WXTextWeight:styles[@"fontWeight"]];
        }
        if (styles[@"fontStyle"]) {
            _fontStyle = [WXConvert WXTextStyle:styles[@"fontStyle"]];
        }
        if (styles[@"fontFamily"]) {
            _fontFamily = styles[@"fontFamily"];
        }
        if (styles[@"textAlign"]) {
            _textAlignForStyle = [WXConvert NSTextAlignment:styles[@"textAlign"]];
        }
        if (styles[@"placeholderColor"]) {
            _placeholderColor = [WXConvert UIColor:styles[@"placeholderColor"]];
        }else {
            _placeholderColor = [UIColor colorWithRed:0x99/255.0 green:0x99/255.0 blue:0x99/255.0 alpha:1.0];
        }
    }
    
    return self;
}

#pragma mark - lifeCircle

- (void)viewDidLoad
{
    UIView * view = self.view;
    if ([view isKindOfClass:[UITextField class]]){
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textFiledEditChanged:)
                                                     name:UITextFieldTextDidChangeNotification
                                                   object:view];
    }
    _padding = UIEdgeInsetsZero;
    _border = UIEdgeInsetsZero;
    self.userInteractionEnabled = YES;
    [self setType];
    [self setAutofocus:_autofocus];
    [self setTextFont];
    [self setPlaceholderAttributedString];
    [self setTextAlignment:_textAlignForStyle];
    [self setTextColor:_colorForStyle];
    [self setText:_value];
    [self setEnabled:!_disabled];
    [self setRows:_rows];
    [self setReturnKeyType:_returnKeyType];
    [self updatePattern];
    
    UIBarButtonItem *barButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(closeKeyboard)];
    UIBarButtonItem *space = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 0, 44)];
    toolbar.items = [NSArray arrayWithObjects:space, barButton, nil];
    
    self.inputAccessoryView = toolbar;
    [self handlePseudoClass];
}

- (void)viewWillLoad
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWasShown:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void)focus
{
    if(self.view) {
        [self.view becomeFirstResponder];
    }
}

-(void)blur
{
    if(self.view) {
        [self.view resignFirstResponder];
    }
}

-(void)setSelectionRange:(NSInteger)selectionStart selectionEnd:(NSInteger)selectionEnd
{
    if(selectionStart>self.text.length || selectionEnd>self.text.length) {
        return;
    }
    [self.view becomeFirstResponder];
    [self setEditSelectionRange:selectionStart selectionEnd:selectionEnd];
}

-(void)getSelectionRange:(WXCallback)callback
{
    NSDictionary *res = [self getEditSelectionRange];
    if(callback) {
        callback(res);
    }
}


#pragma mark - Overwrite Method
-(NSString *)text
{
    return @"";
}

- (void)setText:(NSString *)text
{
}

-(void)setTextColor:(UIColor *)color
{
}

-(void)setTextAlignment:(NSTextAlignment)textAlignForStyle
{
}

-(void)setUserInteractionEnabled:(BOOL)userInteractionEnabled
{
}

-(void)setEnabled:(BOOL)enabled
{
}

-(void)setReturnKeyType:(UIReturnKeyType)returnKeyType
{
}

-(void)setInputAccessoryView:(UIView *)inputAccessoryView
{
}

-(void)setEditSelectionRange:(NSInteger)selectionStart selectionEnd:(NSInteger)selectionEnd
{
}

-(NSDictionary *)getEditSelectionRange
{
    return @{};
}

-(void)setKeyboardType:(UIKeyboardType)keyboardType
{
}

-(void)setSecureTextEntry:(BOOL)secureTextEntry
{
}

-(void)setEditPadding:(UIEdgeInsets)padding
{
}

-(void)setEditBorder:(UIEdgeInsets)border
{
}

-(void)setAttributedPlaceholder:(NSMutableAttributedString *)attributedString font:(UIFont *)font
{
}

-(void)setFont:(UIFont *)font
{
}

-(void)setRows:(NSUInteger)rows
{
}

#pragma mark - Add Event
- (void)addEvent:(NSString *)eventName
{
    if ([eventName isEqualToString:@"input"]) {
        _inputEvent = YES;
    }
    if ([eventName isEqualToString:@"focus"]) {
        _focusEvent = YES;
    }
    if ([eventName isEqualToString:@"blur"]) {
        _blurEvent = YES;
    }
    if ([eventName isEqualToString:@"change"]) {
        _changeEvent = YES;
    }
    if ([eventName isEqualToString:@"return"]) {
        _returnEvent = YES;
    }
    if ([eventName isEqualToString:@"click"]) {
        _clickEvent = YES;
    }
    if ([eventName isEqualToString:@"keyboard"]) {
        _keyboardEvent = YES;
    }
}

#pragma Remove Event

-(void)removeEvent:(NSString *)eventName
{
    if ([eventName isEqualToString:@"input"]) {
        _inputEvent = NO;
    }
    if ([eventName isEqualToString:@"focus"]) {
        _focusEvent = NO;
    }
    if ([eventName isEqualToString:@"blur"]) {
        _blurEvent = NO;
    }
    if ([eventName isEqualToString:@"change"]) {
        _changeEvent = NO;
    }
    if ([eventName isEqualToString:@"return"]) {
        _returnEvent = NO;
    }
    if ([eventName isEqualToString:@"click"]) {
        _clickEvent = NO;
    }
    if ([eventName isEqualToString:@"keyboard"]) {
        _keyboardEvent = NO;
    }
}

#pragma mark - upate attributes

- (void)updateAttributes:(NSDictionary *)attributes
{
    _attr = attributes;
    if (attributes[@"type"]) {
        _inputType = [WXConvert NSString:attributes[@"type"]];
        [self setType];
    }
    if (attributes[@"autofocus"]) {
        self.autofocus = [attributes[@"autofocus"] boolValue];
    }
    if (attributes[@"disabled"]) {
        _disabled = [attributes[@"disabled"] boolValue];
        [self setEnabled:!_disabled];
    }
    if (attributes[@"maxlength"]) {
        _maxLength = [NSNumber numberWithInteger:[attributes[@"maxlength"] integerValue]];
    }
    if (attributes[@"placeholder"]) {
        _placeholderString = [WXConvert NSString:attributes[@"placeholder"]]?:@"";
        [self setPlaceholderAttributedString];
    }
    if (attributes[@"value"]) {
        _value = [WXConvert NSString:attributes[@"value"]]?:@"";
        if (_maxLength && [_value length] > [_maxLength integerValue]&& [_maxLength integerValue] >= 0) {
            _value = [_value substringToIndex:([_maxLength integerValue])];
        }
        [self setText:_value];
    }
    if (attributes[@"returnKeyType"]) {
        _returnKeyType = [WXConvert UIReturnKeyType:attributes[@"returnKeyType"]];
        [self setReturnKeyType:_returnKeyType];
    }
    if (attributes[@"rows"]) {
        _rows = [attributes[@"rows"] integerValue];
        [self setRows:_rows];
    } else {
        _rows = 2;
        [self setRows:_rows];
    }
}

#pragma mark - upate styles

- (void)updateStyles:(NSDictionary *)styles
{
    if (styles[@"color"]) {
        _colorForStyle = [WXConvert UIColor:styles[@"color"]];
        [self setTextColor:_colorForStyle];
    }
    if (styles[@"fontSize"]) {
        _fontSize = [WXConvert WXPixelType:styles[@"fontSize"] scaleFactor:self.weexInstance.pixelScaleFactor];
    }
    if (styles[@"fontWeight"]) {
        _fontWeight = [WXConvert WXTextWeight:styles[@"fontWeight"]];
    }
    if (styles[@"fontStyle"]) {
        _fontStyle = [WXConvert WXTextStyle:styles[@"fontStyle"]];
    }
    if (styles[@"fontFamily"]) {
        _fontFamily = [WXConvert NSString:styles[@"fontFamily"]];
    }
    [self setTextFont];
    
    if (styles[@"textAlign"]) {
        _textAlignForStyle = [WXConvert NSTextAlignment:styles[@"textAlign"]];
        [self setTextAlignment:_textAlignForStyle] ;
    }
    if (styles[@"placeholderColor"]) {
        _placeholderColor = [WXConvert UIColor:styles[@"placeholderColor"]];
    }else {
        _placeholderColor = [UIColor colorWithRed:0x99/255.0 green:0x99/255.0 blue:0x99/255.0 alpha:1.0];
    }
    [self setPlaceholderAttributedString];
    [self updatePattern];
}

-(void)updatePattern
{
    UIEdgeInsets padding = UIEdgeInsetsMake(self.cssNode->style.padding[CSS_TOP], self.cssNode->style.padding[CSS_LEFT], self.cssNode->style.padding[CSS_BOTTOM], self.cssNode->style.padding[CSS_RIGHT]);
    if (!UIEdgeInsetsEqualToEdgeInsets(padding, _padding)) {
        [self setPadding:padding];
    }
    
    UIEdgeInsets border = UIEdgeInsetsMake(self.cssNode->style.border[CSS_TOP], self.cssNode->style.border[CSS_LEFT], self.cssNode->style.border[CSS_BOTTOM], self.cssNode->style.border[CSS_RIGHT]);
    if (!UIEdgeInsetsEqualToEdgeInsets(border, _border)) {
        [self setBorder:border];
    }
}

- (CGSize (^)(CGSize))measureBlock
{
    __weak typeof(self) weakSelf = self;
    return ^CGSize (CGSize constrainedSize) {
        
        CGSize computedSize = [[[NSString alloc] init]sizeWithAttributes:nil];
        //TODO:more elegant way to use max and min constrained size
        if (!isnan(weakSelf.cssNode->style.minDimensions[CSS_WIDTH])) {
            computedSize.width = MAX(computedSize.width, weakSelf.cssNode->style.minDimensions[CSS_WIDTH]);
        }
        
        if (!isnan(weakSelf.cssNode->style.maxDimensions[CSS_WIDTH])) {
            computedSize.width = MIN(computedSize.width, weakSelf.cssNode->style.maxDimensions[CSS_WIDTH]);
        }
        
        if (!isnan(weakSelf.cssNode->style.minDimensions[CSS_HEIGHT])) {
            computedSize.height = MAX(computedSize.height, weakSelf.cssNode->style.minDimensions[CSS_HEIGHT]);
        }
        
        if (!isnan(weakSelf.cssNode->style.maxDimensions[CSS_HEIGHT])) {
            computedSize.height = MIN(computedSize.height, weakSelf.cssNode->style.maxDimensions[CSS_HEIGHT]);
        }
        
        return (CGSize) {
            WXCeilPixelValue(computedSize.width),
            WXCeilPixelValue(computedSize.height)
        };
    };
}

#pragma mark WXDatePickerManagerDelegate

-(void)fetchDatePickerValue:(NSString *)value
{
    self.text = value;
    if (_changeEvent) {
        if (![[self text] isEqualToString:_changeEventString]) {
            [self fireEvent:@"change" params:@{@"value":[self text]} domChanges:@{@"attrs":@{@"value":[self text]}}];
        }
    }
}

#pragma mark UITextFieldDelegate

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField{
    if([self isDateType])
    {
        [[[UIApplication sharedApplication] keyWindow] endEditing:YES];
        _changeEventString = [textField text];
        [_datePickerManager show];
        return NO;
    }
    return  YES;
}

#pragma mark UITextFieldDelegate

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    _changeEventString = [textField text];
    if (_focusEvent) {
        [self fireEvent:@"focus" params:nil];
    }
    [self handlePseudoClass];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if (_maxLength) {
        NSUInteger oldLength = [textField.text length];
        NSUInteger replacementLength = [string length];
        NSUInteger rangeLength = range.length;
        
        NSUInteger newLength = oldLength - rangeLength + replacementLength;
        
        return newLength <= [_maxLength integerValue] ;
    }
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    if (_changeEvent) {
        if (![[textField text] isEqualToString:_changeEventString]) {
            [self fireEvent:@"change" params:@{@"value":[textField text]} domChanges:@{@"attrs":@{@"value":[textField text]}}];
        }
    }
    if (_blurEvent) {
        [self fireEvent:@"blur" params:nil];
    }
    if(self.pseudoClassStyles && [self.pseudoClassStyles count]>0){
        [self recoveryPseudoStyles:self.styles];
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (_returnEvent) {
        NSString *typeStr = [WXUtility returnKeyType:_returnKeyType];
        [self fireEvent:@"return" params:@{@"value":[textField text],@"returnKeyType":typeStr} domChanges:@{@"attrs":@{@"value":[textField text]}}];
    }
    return YES;
}

- (void)textFiledEditChanged:(NSNotification *)notifi
{
    if (_inputEvent) {
        UITextField *textField = (UITextField *)notifi.object;
        // bind each other , the key must be attrs
        [self fireEvent:@"input" params:@{@"value":[textField text]} domChanges:@{@"attrs":@{@"value":[textField text]}}];
    }
}

- (void)setViewMovedUp:(BOOL)movedUp
{
    UIView *rootView = self.weexInstance.rootView;
    CGRect rect = self.weexInstance.frame;
    CGRect rootViewFrame = rootView.frame;
    CGRect inputFrame = [self.view.superview convertRect:self.view.frame toView:rootView];
    if (movedUp) {
        CGFloat offset = inputFrame.origin.y-(rootViewFrame.size.height-_keyboardSize.height-inputFrame.size.height);
        if (offset > 0) {
            rect = (CGRect){
                .origin.x = 0.f,
                .origin.y = -offset,
                .size = rootViewFrame.size
            };
        }
    }
    self.weexInstance.rootView.frame = rect;
}

#pragma mark textview Delegate
- (BOOL)textViewShouldBeginEditing:(UITextView *)textView
{
    if([self isDateType])
    {
        [[[UIApplication sharedApplication] keyWindow] endEditing:YES];
        _changeEventString = [textView text];
        [_datePickerManager show];
        return NO;
    }
    return  YES;
}

- (void)textViewDidBeginEditing:(UITextView *)textView
{
    _changeEventString = [textView text];
    if (_focusEvent) {
        [self fireEvent:@"focus" params:nil];
    }
    if (_clickEvent) {
        [self fireEvent:@"click" params:nil];
    }
    [textView becomeFirstResponder];
    [self handlePseudoClass];
}

- (void)textViewDidChange:(UITextView *)textView
{
    if(textView.text && [textView.text length] > 0) {
        self.placeHolderLabel.text = @"";
    }else{
        [self setPlaceholderAttributedString];
    }
    if (_inputEvent) {
        [self fireEvent:@"input" params:@{@"value":[textView text]} domChanges:@{@"attrs":@{@"value":[textView text]}}];
    }
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
    if (![textView.text length]) {
        [self setPlaceholderAttributedString];
    }
    if (_changeEvent) {
        if (![[textView text] isEqualToString:_changeEventString]) {
            [self fireEvent:@"change" params:@{@"value":[textView text]} domChanges:@{@"attrs":@{@"value":[textView text]}}];
        }
    }
    if (_blurEvent) {
        [self fireEvent:@"blur" params:nil];
    }
    if(self.pseudoClassStyles && [self.pseudoClassStyles count]>0){
        [self recoveryPseudoStyles:self.styles];
    }
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    if ([text isEqualToString:@"\n"]) {
        if (_returnEvent) {
            NSString *typeStr = [WXUtility returnKeyType:_returnKeyType];
            [self fireEvent:@"return" params:@{@"value":[textView text],@"returnKeyType":typeStr} domChanges:@{@"attrs":@{@"value":[textView text]}}];
        }
    }
    
    if (_maxLength) {
        NSUInteger oldLength = [textView.text length];
        NSUInteger replacementLength = [text length];
        NSUInteger rangeLength = range.length;
        NSUInteger newLength = oldLength - rangeLength + replacementLength;
        return newLength <= [_maxLength integerValue] ;
    }
    
    return YES;
}

#pragma mark private method

- (BOOL)isDateType
{
    if([_inputType isEqualToString:@"date"] || [_inputType isEqualToString:@"time"])
        return YES;
    return NO;
}

- (void)setPlaceholderAttributedString
{
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:_placeholderString];
    [attributedString addAttribute:NSForegroundColorAttributeName value:_placeholderColor range:NSMakeRange(0, _placeholderString.length)];
    UIFont *font = [WXUtility fontWithSize:_fontSize textWeight:_fontWeight textStyle:_fontStyle fontFamily:_fontFamily scaleFactor:self.weexInstance.pixelScaleFactor];
    [self setAttributedPlaceholder:attributedString font:font];
}

- (void)setTextFont
{
    UIFont *font = [WXUtility fontWithSize:_fontSize textWeight:_fontWeight textStyle:_fontStyle fontFamily:_fontFamily scaleFactor:self.weexInstance.pixelScaleFactor];
    [self setFont:font];
}

- (void)setAutofocus:(BOOL)b
{
    if (b) {
        if([self isDateType])
        {
            [_datePickerManager show];
        }else
        {
            [self.view becomeFirstResponder];
        }
    } else {
        if([self isDateType])
        {
            [_datePickerManager hide];
        }else
        {
            [self.view resignFirstResponder];
        }
    }
}

- (void)setType
{
    [self setKeyboardType:UIKeyboardTypeDefault];
    [self setSecureTextEntry:NO];
    if ([_inputType isEqualToString:@"text"]) {
        [self setKeyboardType:UIKeyboardTypeDefault];
    }else if ([_inputType isEqualToString:@"password"]) {
        [self setSecureTextEntry:YES];
    }else if ([_inputType isEqualToString:@"tel"]) {
        [self setKeyboardType:UIKeyboardTypePhonePad];
    }else if ([_inputType isEqualToString:@"email"]) {
        [self setKeyboardType:UIKeyboardTypeEmailAddress];
    }else if ([_inputType isEqualToString:@"url"]) {
        [self setKeyboardType:UIKeyboardTypeURL];
    }else if ([_inputType isEqualToString:@"number"]) {
        [self setKeyboardType:UIKeyboardTypeNumbersAndPunctuation];
    }else if ([self isDateType]) {
        if (!_datePickerManager) {
            _datePickerManager = [[WXDatePickerManager alloc] init];
            _datePickerManager.delegate = self;
        }
        [_datePickerManager updateDatePicker:_attr];
    }
}

- (void)setPadding:(UIEdgeInsets)padding
{
    _padding = padding;
    [self setEditPadding:padding];
}

- (void)setBorder:(UIEdgeInsets)border
{
    _border = border;
    [self setEditBorder:border];
}

#pragma mark update touch styles
-(void)handlePseudoClass
{
    NSMutableDictionary *styles = [NSMutableDictionary new];
    NSMutableDictionary *recordStyles = [NSMutableDictionary new];
    if(_disabled){
        recordStyles = [self getPseudoClassStylesByKeys:@[@"disabled"]];
        [styles addEntriesFromDictionary:recordStyles];
    }else {
        recordStyles = [NSMutableDictionary new];
        recordStyles = [self getPseudoClassStylesByKeys:@[@"enabled"]];
        [styles addEntriesFromDictionary:recordStyles];
    }
    if ([self.view isFirstResponder]){
        recordStyles = [NSMutableDictionary new];
        recordStyles = [self getPseudoClassStylesByKeys:@[@"focus"]];
        [styles addEntriesFromDictionary:recordStyles];
    }
    NSString *disabledStr = @"enabled";
    if (_disabled){
        disabledStr = @"disabled";
    }
    if ([self.view isFirstResponder]) {
        NSString *focusStr = @"focus";
        recordStyles = [NSMutableDictionary new];
        recordStyles = [self getPseudoClassStylesByKeys:@[focusStr,disabledStr]];
        [styles addEntriesFromDictionary:recordStyles];
    }
    [self updatePseudoClassStyles:styles];
}

#pragma mark keyboard
- (void)keyboardWasShown:(NSNotification*)notification
{
    if(![self.view isFirstResponder]) {
        return;
    }
    CGRect begin = [[[notification userInfo] objectForKey:@"UIKeyboardFrameBeginUserInfoKey"] CGRectValue];
    
    CGRect end = [[[notification userInfo] objectForKey:@"UIKeyboardFrameEndUserInfoKey"] CGRectValue];
    if(begin.size.height <= 44) {
        return;
    }
    _keyboardSize = end.size;
    UIView * rootView = self.weexInstance.rootView;
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    CGRect keyboardRect = (CGRect){
        .origin.x = 0,
        .origin.y = CGRectGetMaxY(screenRect) - _keyboardSize.height - 54,
        .size = _keyboardSize
    };
    CGRect inputFrame = [self.view.superview convertRect:self.view.frame toView:rootView];
    if (keyboardRect.origin.y - inputFrame.size.height <= inputFrame.origin.y) {
        [self setViewMovedUp:YES];
        self.weexInstance.isRootViewFrozen = YES;
    }
    
    if (_keyboardEvent) {
        [self fireEvent:@"keyboard" params:@{ @"isShow": @YES }];
    }
}

- (void)keyboardWillHide:(NSNotification*)notification
{
    if (![self.view isFirstResponder]) {
        return;
    }
    UIView * rootView = self.weexInstance.rootView;
    if (!CGRectEqualToRect(self.weexInstance.frame, rootView.frame)) {
        [self setViewMovedUp:NO];
        self.weexInstance.isRootViewFrozen = NO;
    }
    if (_keyboardEvent) {
        [self fireEvent:@"keyboard" params:@{ @"isShow": @NO }];
    }
}

- (void)closeKeyboard
{
    [self.view resignFirstResponder];
}

#pragma mark -reset color
- (void)resetStyles:(NSArray *)styles
{
    if ([styles containsObject:@"color"]) {
        [self setTextColor:[UIColor blackColor]];
    }
    if ([styles containsObject:@"fontSize"]) {
        _fontSize = WX_TEXT_FONT_SIZE;
        [self setTextFont];
    }
}
@end

