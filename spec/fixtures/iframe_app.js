var app = ZendeskApps.defineApp(null)
  .reopenClass({"location":{"chat":{"chat_sidebar":"https://apps.zopim.com/time-tracking/"}},"noTemplate":[],"singleInstall":false,"signedUrls":false})
  .reopen({
    appName: "ABC",
    appVersion: "1.0.0",
    assetUrlPrefix: "http://localhost:4567/0/",
    appClassName: "app-0",
    author: {
      name: "John Smith",
      email: "john@example.com"
    },
    frameworkVersion: "2.0"
  });

ZendeskApps["ABC"] = app;
