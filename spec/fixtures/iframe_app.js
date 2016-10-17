var app = ZendeskApps.defineApp(null)
  .reopenClass({"noTemplate":[],"singleInstall":false,"signedUrls":false,"location":{"chat":{"chat_sidebar":"https://apps.zopim.com/time-tracking/"}}})
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
