(function() {

  var STATUS_CLOSED = 'closed';

  return {
    defaultState: 'loading',

    requests: {
      fetchBookmarks: {
        url: '/api/v1/bookmarks.json'
      },

      addBookmark: function() {
        return {
          url: '/api/v1/bookmarks.json',
          type: 'POST',
          data: {
            ticket_id: this.ticket().id()
          }
        };
      },

      destroyBookmark: function(toDestroy) {
        return {
          url: helpers.fmt('/api/v1/bookmarks/%@.json', toDestroy),
          type: 'POST',
          data: { _method: 'DELETE' }
        };
      }
    },

    events: {
      'app.activated': 'requestBookmarks',

      'fetchBookmarks.always': function(data) {
        this.renderBookmarks((data || {}).bookmarks);
      },

      'addBookmark.done': function() {
        services.notify(this.I18n.t('add.done', { id: this.ticket().id() }));
      },

      'addBookmark.fail': function() {
        services.notify(this.I18n.t('add.failed', { id: this.ticket().id() }), 'error');
      },

      'addBookmark.always': function() {
        this.ajax('fetchBookmarks');
      },

      'click .bookmark': function(event) {
        event.preventDefault();
        this.ajax('addBookmark');
      },

      'click .destroy': 'destroyBookmark'
    },

    renderBookmarks: function(bookmarks) {
      this.bookmarks = bookmarks;
      this.switchTo('list', {
        bookmarks:            this.bookmarks,
        ticketIsBookmarkable: this.ticketIsBookmarkable()
      });
    },

    ticketIsBookmarkable: function() {
      var status = this.ticket().status() || STATUS_CLOSED;
      if ( status == STATUS_CLOSED ) { return false; }

      var ticketID = this.ticket().id(),
          alreadyBookmarked = _.any(this.bookmarks, function(b) {
            return b.ticket.nice_id === ticketID;
          });

      return !alreadyBookmarked;
    },

    requestBookmarks: function() {
      this.ajax('fetchBookmarks');
    },

    // Get the bookmark ID for a click event within a bookmark <li>
    bookmarkID: function(event) {
      return this.$(event.target)
                 .closest('[data-bookmark-id]')
                 .data('bookmark-id');
    },

    destroyBookmark: function(event) {
      event.preventDefault();
      var toDestroy = this.bookmarkID(event);
      if (!toDestroy) {
        return;
      }

      var self = this;
      this.ajax('destroyBookmark', toDestroy).done(function() {
        self.removeDestroyedBookmark(toDestroy);
      }).fail(function() {
        services.notify(self.I18n.t('destroy.failed'), 'error');
      });
    },

    removeDestroyedBookmark: function(toDestroy) {
      this.renderBookmarks(_.reject(this.bookmarks, function(b) {
        return b.id === toDestroy;
      }));
      services.notify(this.I18n.t('destroy.done'));
    }

  };

}());
