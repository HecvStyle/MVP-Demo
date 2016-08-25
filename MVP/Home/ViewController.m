//
//  ViewController.m
//  MVP
//
//  Created by sunnyvale on 15/12/6.
//  Copyright © 2015年 sunnyvale. All rights reserved.
//

#import "ViewController.h"
#import "TemplateChannelModel.h"
#import "TemplateContainerModel.h"
#import "WebViewController.h"
#import "TemplateCellProtocol.h"
#import "TemplateSorbRenderProtocol.h"
#import "UITableView+Template.h"

#import "TemplateActionHandler.h"
#import "TemplateAction.h"
#import "ViewController+Template.h"

@interface ViewController ()<UITableViewDataSource,UITableViewDelegate,TemplateActionHandlerDelegate>

@property (nonatomic,strong) TemplateChannelModel  *floorModel;
@property (nonatomic,strong) TemplateActionHandler *handler;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.title = @"Index";
    self.view.backgroundColor = [UIColor whiteColor];
    
    [self.tableView registTableViewCell];
    [self addShareBarButtonItemWihtModel:nil];
    
    [self fetchData];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.contentInset = UIEdgeInsetsMake(-64, 0, 0, 0);
    self.tableView.mj_header = [MJRefreshNormalHeader headerWithRefreshingBlock:^{
        // 进入刷新状态后会自动调用这个block
    }];
    //或
    // 设置回调（一旦进入刷新状态，就调用target的action，也就是调用self的loadNewData方法）
    self.tableView.mj_header = [MJRefreshNormalHeader headerWithRefreshingTarget:self refreshingAction:@selector(loadNewData)];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)loadNewData
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.tableView.mj_header endRefreshing];
    });
}

// block回传用户的点击操作。这里的 model应该提供了所需的业务数据
- (TapBlock)tapBlockForModel:(id<TemplateRenderProtocol>)model
{
    __weak typeof (self) weakself = self;
    return ^(NSIndexPath * indexPath){
        if ([model conformsToProtocol:@protocol(TemplateActionProtocol)]) {
            TemplateAction *action = [(id<TemplateActionProtocol>)model jumpFloorModelAtIndexPath:indexPath];
            [weakself.handler handlerAction:action];
        }
    };
}

- (void)fetchData
{
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    [manager setRequestSerializer:[AFHTTPRequestSerializer serializer]];
    [manager setResponseSerializer:[AFHTTPResponseSerializer serializer]];
    
    __weak typeof (self) weakself = self;
    [SVProgressHUD show];
    [manager GET:@"http://7sbrak.com1.z0.glb.clouddn.com/food.json"
      parameters:nil
         success:^(NSURLSessionDataTask *task, id responseObject){
             NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:responseObject options:NSUTF8StringEncoding error:nil];
             weakself.floorModel = [TemplateChannelModel mj_objectWithKeyValues:dic];
             [_tableView.mj_header endRefreshing];
             [SVProgressHUD dismiss];

             //更新UI
             [weakself.tableView reloadData];
         }
         failure:^(NSURLSessionDataTask *task, NSError *error){
             [SVProgressHUD dismiss];
         }];
}

#pragma mark - UITableViewDataSource,UITableViewDelegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	//这里应该是拿到了整个楼层，每个楼层中有个各种不同的的cell
    return [self.floorModel.floors count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
 /**
  *  这里是获取了单个section中的cell 个数。并且可以发现 list 也是一个TemplateContainerModel，实现了TemplateContainerModel协议，这个协议一方面确定了这个section多少个cell，通过这个方法numberOfChildModelsInContainer，另一个方面，则是确定了这个每个cell UI样式的model，通过 childFloorModelAtIndex 方法获取，来确定每个cell改用什么样的样式
  */
    TemplateContainerModel<TemplateContainerProtocol> *list = self.floorModel.floors[section];
    return [list numberOfChildModelsInContainer];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	// 这句代码就是通过indexpath 获取对应cell 的渲染样式的model，rowModelAtIndexPath 这个方法内部调用了 childFloorModelAtIndex（上面提到了），并且这个model实现了 TemplateRenderProtocol协议，这个协议就是通过 一个 identify，来匹配对应的cell，因为每个类型的cell都有对应的标志。
    id <TemplateRenderProtocol> model = [self.floorModel rowModelAtIndexPath:indexPath];
    UITableViewCell <TemplateCellProtocol> * cell = [tableView dequeueReusableCellWithIdentifier:[model floorIdentifier]];
	// 这里cell用了向上转型，父类指针指向了子类，其实，这里实际的cell，应该是对应的identify 的cell，并且这些cell都实现了 TemplateCellProtocol 协议，processData 方法用来铜鼓model渲染cell的样式，tapOnePlace 方法则用来处理用户点击cell的操作，而这个操作，其实并没有在cell内部实现，而是通过block传回来了

    [cell processData:model];
    [cell tapOnePlace:[self tapBlockForModel:model]];
    if(!cell){
        return [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    }else{
        return (UITableViewCell *)cell;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{

	//依然是先拿到 渲染的cell的model
    id <TemplateRenderProtocol>  floor = [self.floorModel rowModelAtIndexPath:indexPath];

	// 先判断这个cell是不是实现了 floorIdentifier 这个协议中定义的方法，实现了才能去拿cell的高度，
    if ([floor respondsToSelector:@selector(floorIdentifier)]) {
        NSString *cellIdentifier = [floor floorIdentifier];

		// 这里其实就是获取需要渲染的对应的cell，通过 cellIdentifier。
        Class<TemplateCellProtocol> viewClass = NSClassFromString(cellIdentifier);

		// 因为cell实现了TemplateCellProtocol 协议的，所以在自己内部应该可以通过 floor 这个model来算出需要的真实高度，并且给出了cell的宽度适配
        CGSize size = [viewClass calculateSizeWithData:floor constrainedToSize:CGSizeMake(tableView.frame.size.width, 0.0)];
        return size.height;
    }
    return 0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
	// floor 中有对应的fheaer 字段，该字段专门用于header 的渲染model，因为header 跟着section对应，所以这个字段可以放在容器模型中。 这里的处理和对cell 的处理上相同的方式。
    id <TemplateSorbRenderProtocol,TemplateRenderProtocol> floor = self.floorModel.floors[section];
    if ([floor conformsToProtocol:@protocol(TemplateSorbRenderProtocol)]) {
        NSString *headerIdentifier = [floor headerFloorIdentifier];
        if (headerIdentifier) {
            Class<TemplateCellProtocol> viewClass = NSClassFromString(headerIdentifier);
            CGSize size = [viewClass calculateSizeWithData:floor constrainedToSize:CGSizeMake(tableView.frame.size.width, 0.0)];
            return size.height;
        }
    }

    return 0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    id <TemplateSorbRenderProtocol,TemplateRenderProtocol> floor = self.floorModel.floors[section];
    if ([floor conformsToProtocol:@protocol(TemplateSorbRenderProtocol)]) {
        id<TemplateSorbRenderProtocol> headerModel = [floor headerFloorModelAtIndex:section];
        if (headerModel) {
            NSString *identifier = [headerModel headerFloorIdentifier];
            UIView <TemplateCellProtocol> *headerView = (UIView <TemplateCellProtocol> *)[tableView dequeueReusableHeaderFooterViewWithIdentifier:identifier];
            [headerView processData:floor];
            return headerView;
        }
    }
    return nil;
}

#pragma makk - set get

- (TemplateActionHandler *)handler
{
    if (!_handler) {
        _handler = [[TemplateActionHandler alloc] init];
        _handler.delegate = self;
    }
    return _handler;
}

@end
