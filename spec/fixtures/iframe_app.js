var app = ZendeskApps.defineApp(null)
  .reopenClass({"experiments":{"hashParams":true},"location":{"chat":{"chat_sidebar":{"url":"https://apps.zopim.com/time-tracking/"}}},"noTemplate":[],"singleInstall":false,"signedUrls":false})
  .reopen({
    appName: "ABC",
    appVersion: "1.0.0",
    locationIcons: {},
    assetUrlPrefix: "http://localhost:4567/0/",
    logoAssetHash: {"chat":"logo-small.png"},
    appClassName: "app-0",
    author: {
      name: "John Smith",
      email: "john@example.com"
    },
    frameworkVersion: "2.0"
  });

ZendeskApps["ABC"] = app;
