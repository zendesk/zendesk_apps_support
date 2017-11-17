var app = ZendeskApps.defineApp(null)
  .reopenClass({"experiments":{"hashParams":true},"location":{"support":{"top_bar":{"url":"assets/support/index.html"},"nav_bar":{"url":"assets/support/index.html"}},"chat":{"chat_sidebar":{"url":"assets/chat/index.html"}}},"noTemplate":[],"singleInstall":false,"signedUrls":false})
  .reopen({
    appName: "ABC",
    appVersion: "1.0.0",
    locationIcons: {"support":{"top_bar":{"inactive":"support/icon_top_bar_inactive.png","active":"support/icon_top_bar_active.png","hover":"support/icon_top_bar_hover.png"},"nav_bar":{"svg":"support/icon_nav_bar.svg"}}},
    assetUrlPrefix: "http://localhost:4567/0/",
    logoAssetHash: {"support":"support/logo-small.png","chat":"chat/logo-small.png"},
    appClassName: "app-0",
    author: {
      name: "John Smith",
      email: "john@example.com"
    },
    frameworkVersion: "2.0"
  });

ZendeskApps["ABC"] = app;
