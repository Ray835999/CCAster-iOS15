#import "CCARootListController.h"
#import <Preferences/PSSpecifier.h>
#import <spawn.h>
#import <unistd.h>

extern char **environ;

@interface CCARootListController ()
@property (nonatomic, assign) BOOL initialEnabledValue;
@end

@implementation CCARootListController

- (NSArray *)specifiers {
    if (!_specifiers) _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    return _specifiers;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    for (PSSpecifier *specifier in self.specifiers) {
        if ([[specifier propertyForKey:@"key"] isEqualToString:@"Enabled"]) {
            self.initialEnabledValue = [[self readPreferenceValue:specifier] boolValue];
            break;
        }
    }
    self.navigationItem.rightBarButtonItem = nil;
}

- (void)setMasterEnabled:(id)value specifier:(PSSpecifier *)specifier {
    [self setPreferenceValue:value specifier:specifier];
    BOOL needsRespring = [value boolValue] != self.initialEnabledValue;
    if (!needsRespring) {
        self.navigationItem.rightBarButtonItem = nil;
        return;
    }
    if (self.navigationItem.rightBarButtonItem) return;

    UIImage *image = [UIImage systemImageNamed:@"arrow.clockwise"];
    UIBarButtonItem *button = [[UIBarButtonItem alloc] initWithImage:image
                                                               style:UIBarButtonItemStylePlain
                                                              target:self
                                                              action:@selector(respring)];
    button.accessibilityLabel = @"Respring";
    self.navigationItem.rightBarButtonItem = button;
}

- (void)respring {
    const char *path = access("/var/jb/usr/bin/sbreload", X_OK) == 0
        ? "/var/jb/usr/bin/sbreload"
        : "/usr/bin/sbreload";
    const char *arguments[] = { path, NULL };
    pid_t pid = 0;
    posix_spawn(&pid, path, NULL, NULL, (char *const *)arguments, environ);
}

@end
