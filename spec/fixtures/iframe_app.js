var app = ZendeskApps.defineApp(null)
  .reopenClass({"location":{"zopim":{"chat_sidebar":"https://apps.zopim.com/time-tracking/"}},"noTemplate":false,"singleInstall":false,"signedUrls":false})
  .reopen({
    appName: "ABC",
    appVersion: "1.0.0",
    assetUrlPrefix: "http://localhost:4567/0/",
    appClassName: "app-0",
    author: {
      name: "John Smith",
      email: "john@example.com"
    },
    frameworkVersion: "1.0"
  });

ZendeskApps["ABC"] = app;
