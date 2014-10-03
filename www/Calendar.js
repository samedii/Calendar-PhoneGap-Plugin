(function() {
    "use strict";

    cordova.addConstructor(function installCalendarPlugin() {

        if (!window.plugins) {
            window.plugins = {};
        }

        window.plugins.calendar = {
            listCalendars: function(successCallback, errorCallback) {
                cordova.exec(successCallback, errorCallback, "Calendar", "listCalendars", []);
            },

            getCalendarWithId: function(calendarId, successCallback, errorCallback) {
                cordova.exec(successCallback, errorCallback, "Calendar", "getCalendarWithId", [calendarId]);
            },

            saveCalendar: function(calendar, successCallback, errorCallback) {
                cordova.exec(successCallback, errorCallback, "Calendar", "saveCalendar", calendar);
            },

            deleteCalendarWithId: function(calendarId, successCallback, errorCallback) {
                cordova.exec(successCallback, errorCallback, "Calendar", "deleteCalendarWithId", [calendarId]);
            },

            listEvents: function(options, successCallback, errorCallback) {
                cordova.exec(successCallback, errorCallback, "Calendar", "listEvents", options);
            },

            getEventWithId: function(eventId, successCallback, errorCallback) {
                cordova.exec(successCallback, errorCallback, "Calendar", "getEventWithId", [eventId]);
            },

            /*
//Useful on android? For later
createEventInteractively : function (options, successCallback, errorCallback) {
  cordova.exec(successCallback, errorCallback, "Calendar", "createEventInteractively", [options]);
};*/

            saveEvent: function(anEvent, successCallback, errorCallback) {
                cordova.exec(successCallback, errorCallback, "Calendar", "saveEvent", anEvent);
            },

            deleteEventWithId: function(eventId, successCallback, errorCallback) {
                cordova.exec(successCallback, errorCallback, "Calendar", "deleteEventWithId", [eventId]);
            },

            findMatchingEvents: function(partialEvent, successCallback, errorCallback) {
                cordova.exec(successCallback, errorCallback, "Calendar", "findMatchingEvents", partialEvent);
            },

            deleteMatchingEvents: function(partialEvent, successCallback, errorCallback) {
                cordova.exec(successCallback, errorCallback, "Calendar", "deleteMatchingEvents", partialEvent);
            }
        };

        return window.plugins.calendar;
    });

})();
