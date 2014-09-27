"use strict";
function Calendar() {
}

Calendar.prototype.createCalendar = function (options, successCallback, errorCallback) {
  cordova.exec(successCallback, errorCallback, "Calendar", "createCalendar", [options]);
};

Calendar.prototype.deleteCalendar = function (calendarName, successCallback, errorCallback) {
  cordova.exec(successCallback, errorCallback, "Calendar", "deleteCalendar", [{
    "calendarName": calendarName
  }]);
};

/**
 * This method can be used if you want more control over the event details.
 * Pass in an options object which you can easily override as follow:
 *   var options = window.plugins.calendar.getCalendarOptions();
 *   options.firstReminderMinutes = 150;
 */
Calendar.prototype.createEvent = function (eventOptions, successCallback, errorCallback) {
  cordova.exec(successCallback, errorCallback, "Calendar", "createEventWithOptions", [eventOptions])
};

Calendar.prototype.createEventInteractively = function (options, successCallback, errorCallback) {
  cordova.exec(successCallback, errorCallback, "Calendar", "createEventInteractively", [options]);
};

Calendar.prototype.deleteEventWithId = function (eventId, successCallback, errorCallback) {
  cordova.exec(successCallback, errorCallback, "Calendar", "deleteEventWithId", [eventId]);
};

Calendar.prototype.deleteMatchingEvents = function (title, location, notes, startTime, endTime, successCallback, errorCallback) {
  cordova.exec(successCallback, errorCallback, "Calendar", "deleteEvent", [{
    "title": title,
    "location": location,
    "notes": notes,
    "startTime": startTime,
    "endTime": endTime
  }])
};

Calendar.prototype.deleteEventFromNamedCalendar = function (title, location, notes, startTime, endTime, calendarName, successCallback, errorCallback) {
  cordova.exec(successCallback, errorCallback, "Calendar", "deleteEventFromNamedCalendar", [{
    "title": title,
    "location": location,
    "notes": notes,
    "startTime": startTime,
    "endTime": endTime,
    "calendarName": calendarName
  }])
};

Calendar.prototype.findEvents = function (title, location, notes, startTime, endTime, successCallback, errorCallback) {
  cordova.exec(successCallback, errorCallback, "Calendar", "findEvent", [{
    "title": title,
    "location": location,
    "notes": notes,
    "startTime": startTime,
    "endTime": endTime
  }])
};

Calendar.prototype.findAllEventsInNamedCalendar = function (calendarName, successCallback, errorCallback) {
  cordova.exec(successCallback, errorCallback, "Calendar", "findAllEventsInNamedCalendar", [{
    "calendarName": calendarName
  }]);
};

Calendar.prototype.saveEvent = function (anEvent, successCallback, errorCallback) {
  cordova.exec(successCallback, errorCallback, "Calendar", "saveEvent", [anEvent]);
};

Calendar.prototype.modifyEvent = function (title, location, notes, startTime, endTime, newTitle, newLocation, newNotes, newStartTime, newEndTime, successCallback, errorCallback) {

  cordova.exec(successCallback, errorCallback, "Calendar", "modifyEvent", [{
    "title": title,
    "location": location,
    "notes": notes,
    "startTime": startTime,
    "endTime": endTime,
    "newTitle": newTitle,
    "newLocation": newLocation,
    "newNotes": newNotes,
    "newStartTime": newStartTime,
    "newEndTime": newEndTime
  }])
};

Calendar.prototype.modifyEventInNamedCalendar = function (title, location, notes, startTime, endTime, newTitle, newLocation, newNotes, newStartTime, newEndTime, calendarName, successCallback, errorCallback) {

  cordova.exec(successCallback, errorCallback, "Calendar", "modifyEventInNamedCalendar", [{
    "title": title,
    "location": location,
    "notes": notes,
    "startTime": startTime,
    "endTime": endTime,
    "newTitle": newTitle,
    "newLocation": newLocation,
    "newNotes": newNotes,
    "newStartTime": newStartTime,
    "newEndTime": newEndTime,
    "calendarName": calendarName
  }])
};

Calendar.prototype.listEventsInRange = function (startTime, endTime, successCallback, errorCallback) {
  cordova.exec(successCallback, errorCallback, "Calendar", "listEventsInRange", {
    "startTime": startTime,
    "endTime": endTime
  })
};

Calendar.prototype.listEventsWithOptions = function (options, successCallback, errorCallback) {
  cordova.exec(successCallback, errorCallback, "Calendar", "listEventsInRange", [options]);
};

Calendar.prototype.listCalendars = function (successCallback, errorCallback) {
  cordova.exec(successCallback, errorCallback, "Calendar", "listCalendars", []);
};

Calendar.install = function () {
  if (!window.plugins) {
    window.plugins = {};
  }

  window.plugins.calendar = new Calendar();
  return window.plugins.calendar;
};

cordova.addConstructor(Calendar.install);
