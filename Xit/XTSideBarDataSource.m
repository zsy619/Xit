//
//  XTSideBarDataSource.m
//  Xit
//
//  Created by German Laullon on 17/07/11.
//

#import "XTSideBarDataSource.h"
#import "XTSideBarItem.h"
#import "Xit.h"
#import "XTLocalBranchItem.h"
#import "XTTagItem.h"
#import "XTRemotesItem.h"
#import "NSMutableDictionary+MultiObjectForKey.h"

@implementation XTSideBarDataSource

- (id)init
{
    self = [super init];
    if (self) {
        XTSideBarItem *branchs=[[XTSideBarItem alloc] initWithTitle:@"Branchs"];
        XTSideBarItem *tags=[[XTSideBarItem alloc] initWithTitle:@"Tags"];
        XTRemotesItem *remotes=[[XTRemotesItem alloc] initWithTitle:@"Remotes"];
        XTSideBarItem *stashes=[[XTSideBarItem alloc] initWithTitle:@"Stashes"];
        roots=[NSArray arrayWithObjects:branchs,tags,remotes,stashes,nil];
    }
    
    return self;
}

-(void)setRepo:(Xit *)newRepo
{
    repo=newRepo;
    [repo addObserver:self forKeyPath:@"reload" options:NSKeyValueObservingOptionNew context:nil];
    [self reload];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if([keyPath isEqualToString:@"reload"]){
        NSArray *reload=[change objectForKey:NSKeyValueChangeNewKey];
        for(NSString *path in reload){
            if([path hasPrefix:@".git/refs/"]){
                [self reload];
                break;
            }
        }
    }
}

-(void)reload
{
    [self willChangeValueForKey:@"reload"];
    NSMutableDictionary *refsIndex=[NSMutableDictionary dictionary];
    [self reloadBrachs:refsIndex];
    [self reloadStashes:refsIndex];
    repo.refsIndex=refsIndex;
    [outline reloadData];
    [self didChangeValueForKey:@"reload"];
}

-(void)reloadStashes:(NSMutableDictionary *)refsIndex
{
    XTSideBarItem *stashes=[roots objectAtIndex:XT_STASHES];
    [stashes clean];
    NSData *output=[repo exectuteGitWithArgs:[NSArray arrayWithObjects:@"stash",@"list",@"--pretty=%H %gd %gs",nil] error:nil];
    if(output){
        NSString *refs = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
        NSScanner *scan = [NSScanner scannerWithString:refs];
        NSString *commit;
        NSString *name;
        while ([scan scanUpToString:@" " intoString:&commit]) {
            [scan scanUpToString:@"\n" intoString:&name];
            XTSideBarItem *stash=[[XTSideBarItem alloc] initWithTitle:name];
            [stashes addchildren:stash];
            [refsIndex addObject:stash forKey:commit];
        }
    }
}

-(void)reloadBrachs:(NSMutableDictionary *)refsIndex
{
    XTSideBarItem *branchs=[roots objectAtIndex:XT_BRANCHS];
    XTSideBarItem *tags=[roots objectAtIndex:XT_TAGS];
    XTRemotesItem *remotes=[roots objectAtIndex:XT_REMOTES];
    
    NSMutableDictionary *tagIndex=[NSMutableDictionary dictionary];
    
    [branchs clean];
    [tags clean];
    [remotes clean];
    NSData *output=[repo exectuteGitWithArgs:[NSArray arrayWithObjects:@"show-ref",@"-d",nil] error:nil];
    if(output){
        NSString *refs = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
        NSScanner *scan = [NSScanner scannerWithString:refs];
        NSString *commit;
        NSString *name;
        while ([scan scanUpToString:@" " intoString:&commit]) {
            [scan scanUpToString:@"\n" intoString:&name];
            if([name hasPrefix:@"refs/heads/"]){
                XTLocalBranchItem *branch=[[XTLocalBranchItem alloc] initWithTitle:[name lastPathComponent] andSha:commit];
                [branchs addchildren:branch];
                [refsIndex addObject:branch forKey:branch.sha];
            }else if([name hasPrefix:@"refs/tags/"]){
                XTTagItem *tag;
                NSString *tagName=[name lastPathComponent];
                if([tagName hasSuffix:@"^{}"]){
                    tagName=[tagName substringToIndex:tagName.length-3];
                    tag=[tagIndex objectForKey:tagName];
                    tag.sha=commit;
                }else {
                    tag=[[XTTagItem alloc] initWithTitle:tagName andSha:commit];
                    [tags addchildren:tag];
                    [tagIndex setObject:tag forKey:tagName];
                }
                [refsIndex addObject:tag forKey:tag.sha];
            }else if([name hasPrefix:@"refs/remotes/"]){
                NSString *remoteName=[[name pathComponents] objectAtIndex:2];
                NSString *branchName=[name lastPathComponent];
                XTSideBarItem *remote=[remotes getRemote:remoteName];
                if(remote==nil){
                    remote=[[XTSideBarItem alloc] initWithTitle:remoteName];
                    [remotes addchildren:remote];
                }
                XTLocalBranchItem *branch=[[XTLocalBranchItem alloc] initWithTitle:branchName andSha:commit];
                [remote addchildren:branch];
                [refsIndex addObject:branch forKey:branch.sha];
            }
        }
    }
}

#pragma mark - NSOutlineViewDataSource

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
    outline=outlineView;
    outlineView.delegate=self;
    
    NSInteger res=0;
    if(item==nil){
        res=[roots count];
    }else if([item isKindOfClass:[XTSideBarItem class]]){
        XTSideBarItem *sbItem=(XTSideBarItem *)item;
        res=[sbItem numberOfChildrens];
    }    
    return res;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    BOOL res=NO;
    if([item isKindOfClass:[XTSideBarItem class]]){
        XTSideBarItem *sbItem=(XTSideBarItem *)item;
        res=[sbItem isItemExpandable];
    }
    return res;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
    id res=nil;
    if(item==nil){
        res=[roots objectAtIndex:index];
    }else if([item isKindOfClass:[XTSideBarItem class]]){
        XTSideBarItem *sbItem=(XTSideBarItem *)item;
        res=[sbItem children:index];
    }
    return res;
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
    NSString *res=nil;
    if([item isKindOfClass:[XTSideBarItem class]]){
        XTSideBarItem *sbItem=(XTSideBarItem *)item;
        res=[sbItem title];
    }
    return res;
}

#pragma mark - NSOutlineViewDelegate

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
    XTSideBarItem *item=[outline itemAtRow:outline.selectedRow];
    if(item.sha!=nil)
        repo.selectedCommit=item.sha;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
    XTSideBarItem *i=(XTSideBarItem *)item;
    return (i.sha!=nil);
}

@end