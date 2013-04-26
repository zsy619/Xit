//
//  XTSideBarDataSource.h
//  Xit
//
//  Created by German Laullon on 17/07/11.
//

#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>
#import "XTConstants.h"

@class XTHistoryViewController;
@class XTLocalBranchItem;
@class XTRefFormatter;
@class XTRepository;
@class XTSideBarItem;

@interface XTSideBarDataSource : NSObject <NSOutlineViewDataSource, NSOutlineViewDelegate>
{
    @private
    XTRepository *repo;
    NSArray *roots;
    NSOutlineView *outline;
    NSString *currentBranch;
    IBOutlet XTHistoryViewController *viewController;
    IBOutlet XTRefFormatter *refFormatter;
}

- (void)setRepo:(XTRepository *)repo;
- (void)reload;
- (void)reloadBranches:(NSMutableArray *)branches tags:(NSMutableArray *)tags remotes:(NSMutableArray *)remotes refsIndex:(NSMutableDictionary *)refsIndex;
- (void)reloadStashes:(NSMutableArray *)stashes refsIndex:(NSMutableDictionary *)refsIndex;

- (XTSideBarItem *)itemNamed:(NSString *)name inGroup:(NSInteger)groupIndex;

@property (readonly) NSArray *roots;

@end
