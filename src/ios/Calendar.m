#import "Calendar.h"
#import <Cordova/CDV.h>
#import <EventKitUI/EventKitUI.h>
#import <EventKit/EventKit.h>

#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)

@implementation Calendar
@synthesize eventStore;

#pragma mark Initialisation functions

- (CDVPlugin*) initWithWebView:(UIWebView*)theWebView {
    self = (Calendar*)[super initWithWebView:theWebView];
    if (self) {
        [self initEventStoreWithCalendarCapabilities];
    }
    return self;
}

- (void)initEventStoreWithCalendarCapabilities {
    __block BOOL accessGranted = NO;
    eventStore= [[EKEventStore alloc] init];
    if([eventStore respondsToSelector:@selector(requestAccessToEntityType:completion:)]) {
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        [eventStore requestAccessToEntityType:EKEntityTypeEvent completion:^(BOOL granted, NSError *error) {
            accessGranted = granted;
            dispatch_semaphore_signal(sema);
        }];
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    } else { // we're on iOS 5 or older
        accessGranted = YES;
    }
    
    if (accessGranted) {
        self.eventStore = eventStore;
    }
}

#pragma mark Helper Functions

// Assumes input like "#00FF00" (#RRGGBB)
- (UIColor *)colorFromHexString:(NSString *)hexString {
    unsigned rgbValue = 0;
    NSScanner *scanner = [NSScanner scannerWithString:hexString];
    [scanner setScanLocation:1]; // bypass '#' character
    [scanner scanHexInt:&rgbValue];
    return [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0 green:((rgbValue & 0xFF00) >> 8)/255.0 blue:(rgbValue & 0xFF)/255.0 alpha:1.0];
}

+ (NSString*)hexFromColor:(UIColor*)color {
    NSString *webColor = nil;
    
    // This method only works for RGB colors
    if (color &&
        CGColorGetNumberOfComponents(color.CGColor) == 4)
    {
        // Get the red, green and blue components
        const CGFloat *components = CGColorGetComponents(color.CGColor);
        
        // These components range from 0.0 till 1.0 and need to be converted to 0 till 255
        CGFloat red, green, blue;
        red = roundf(components[0] * 255.0);
        green = roundf(components[1] * 255.0);
        blue = roundf(components[2] * 255.0);
        
        // Convert with %02x (use 02 to always get two chars)
        webColor = [[NSString alloc]initWithFormat:@"%02x%02x%02x", (int)red, (int)green, (int)blue];
    }
    
    return webColor;
}

- (NSDictionary*)calendarToDict:(EKCalendar*)calendar {
    return @{
             @"name": [calendar title] ? [calendar title] : [NSNull null],
             @"id": calendar.calendarIdentifier ? calendar.calendarIdentifier : [NSNull null],
             //@"color": colorString,
             @"allowsModify": [NSNumber numberWithBool:calendar.allowsContentModifications]
             };
}

- (NSDictionary*)eventToDict:(EKEvent*)event {
    NSTimeInterval start = [event.startDate timeIntervalSince1970]*1000; //Unix offset format
    NSTimeInterval end = [event.endDate timeIntervalSince1970]*1000;
    
    //CGColorRef color = [event.calendar CGColor];
    //NSString *colorString = [CIColor colorWithCGColor:color].stringRepresentation;
    
    return @{
             @"title": event.title ? event.title : [NSNull null],
             @"location": event.location ? event.location : [NSNull null],
             @"notes": event.notes ? event.notes : [NSNull null],
             @"startTime": [NSNumber numberWithDouble:start],
             @"endTime": [NSNumber numberWithDouble:end],
             @"allDay": [NSNumber numberWithBool: event.allDay],
             @"id": event.eventIdentifier,
             //@"alarms":
             //@"recurrenceRules":
             @"calendar": [self calendarToDict:event.calendar]
             };
}

- (NSMutableArray*)eventsToDicts:(NSArray*)matchingEvents {
    
    NSMutableArray *finalResults = [[NSMutableArray alloc] initWithCapacity:matchingEvents.count];
    
    // Stringify the results - Cordova can't deal with Obj-C objects
    for (EKEvent * event in matchingEvents) {
        [finalResults addObject:[self eventToDict:event]];
    }
    
    return finalResults;
}

-(NSNumber*)unixOffsetFromDate:(NSDate*)date {
    if(date == nil || [[NSNull null] isEqual:date])
        return nil;
    return [NSNumber numberWithDouble:[date timeIntervalSince1970]*1000]; //add ms
}

-(NSDate*)dateFromUnixOffset:(NSNumber*)offset {
    if(offset == nil || [[NSNull null] isEqual:offset])
        return nil;
    return [NSDate dateWithTimeIntervalSince1970:[offset doubleValue]/1000]; //remove ms
}

- (BOOL) isAllDayFromStartDate:(NSDate*)start toEndDate:(NSDate*)end {
    return [self isAllDayFromStart:[self unixOffsetFromDate:start] toEnd:[self unixOffsetFromDate:end]];
}

- (BOOL) isAllDayFromStart:(NSNumber*)start toEnd:(NSNumber*)end {

    NSTimeInterval startTime = [start doubleValue];
    NSTimeInterval endTime = [end doubleValue];
    
    int duration = endTime - startTime;
    int moduloDay = duration % (60*60*24*1000);

    return moduloDay == 0;
}

- (EKCalendar*)calendarWithId:(NSString*)calendarId {
    //Using EventStore calendarWithIdentifier: causes a lot of errors to be fired (works though)
    NSArray *calendars = [self.eventStore calendarsForEntityType:EKEntityTypeEvent];
    for(EKCalendar *calendar in calendars) {
        if([calendar.calendarIdentifier isEqualToString:calendarId])
            return calendar;
    }
    return nil;
}

- (NSArray*)calendarsFromIds:(NSArray*)calendarIds {
    
    NSMutableArray *calendars = [NSMutableArray arrayWithCapacity:[calendarIds count]];
    for(NSString *calendarId in calendarIds) {
        EKCalendar *calendar = [self calendarWithId:calendarId];
        if(calendar)
            [calendars addObject:calendar];
    }
    return calendars;
}

-(EKRecurrenceFrequency) toEKRecurrenceFrequency:(NSString*) recurrence {
    if ([recurrence isEqualToString:@"daily"]) {
        return EKRecurrenceFrequencyDaily;
    } else if ([recurrence isEqualToString:@"weekly"]) {
        return EKRecurrenceFrequencyWeekly;
    } else if ([recurrence isEqualToString:@"monthly"]) {
        return EKRecurrenceFrequencyMonthly;
    } else if ([recurrence isEqualToString:@"yearly"]) {
        return EKRecurrenceFrequencyYearly;
    }
    // default to daily, so invoke this method only when recurrence is set
    return EKRecurrenceFrequencyDaily;
}

-(CDVPluginResult*)modifyEvent:(EKEvent*)event withOptions:(NSDictionary*)options {
    
    event.title = [options objectForKey:@"title"] ? [options objectForKey:@"title"] : event.title;
    event.location = [options objectForKey:@"location"] ? [options objectForKey:@"location"] : event.location;
    event.notes = [options objectForKey:@"notes"] ? [options objectForKey:@"notes"] : event.notes;
    
    NSNumber
        *start  = [options objectForKey:@"startTime"],
        *end    = [options objectForKey:@"endTime"];
    
    NSDate
        *startDate = [self dateFromUnixOffset:start],
        *endDate = [self dateFromUnixOffset:end];
    
    event.startDate = startDate ? startDate : event.startDate;
    event.endDate = endDate ? endDate : event.endDate;
    
    NSNumber *allDay = [options objectForKey:@"allDay"];
    if(allDay)
        event.allDay = [allDay boolValue];
    else
        event.allDay = [self isAllDayFromStart:start toEnd:end];
    
    
    //TODO: This can probably be done better
    
    NSDictionary* calendarOptions = [options objectForKey:@"calendar"];
    
    NSString* calendarId = [calendarOptions objectForKey:@"calendarId"];
    
    
    if(![event.calendar.calendarIdentifier isEqualToString:calendarId]) {
        
        EKCalendar *calendar;
        
        NSString* calendarName = [calendarOptions objectForKey:@"calendarName"];
        
        if(calendarId) {
            calendar = [self.eventStore calendarWithIdentifier:calendarId];
            
            if (calendar == nil) {
                return [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Could not find calendar id"];
            }
            
        } else if(calendarName) {
            calendar = [self findEKCalendar:calendarName];
            
            if (calendar == nil) {
                return [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Could not find calendar name"];
            }
            
        }
        else {
            calendar = self.eventStore.defaultCalendarForNewEvents;
            
            if (calendar == nil) {
                return [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No default calendar found. Is access to the Calendar blocked for this app?"];
            }
        }
        
        event.calendar = calendar;
        
    }
    
    if(!event.calendar.allowsContentModifications) {
        return [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Calendar doesn't allow content modifications"];
    }
    
    
    //TODO: Make arrays of all this
    
    NSDictionary* alarms = [options objectForKey:@"alarms"];
    NSNumber* firstReminderMinutes = [alarms objectForKey:@"firstReminderMinutes"];
    NSNumber* secondReminderMinutes = [alarms objectForKey:@"secondReminderMinutes"];
    
    NSDictionary* recurrenceRules = [options objectForKey:@"recurrenceRules"];
    NSString* recurrence = [recurrenceRules objectForKey:@"recurrence"];
    NSString* recurrenceEndTime = [recurrenceRules objectForKey:@"recurrenceEndTime"];
    
    if (firstReminderMinutes && firstReminderMinutes != (id)[NSNull null]) {
        EKAlarm *reminder = [EKAlarm alarmWithRelativeOffset:-1*firstReminderMinutes.intValue*60];
        [event addAlarm:reminder];
    }
    
    if (secondReminderMinutes && secondReminderMinutes != (id)[NSNull null]) {
        EKAlarm *reminder = [EKAlarm alarmWithRelativeOffset:-1*secondReminderMinutes.intValue*60];
        [event addAlarm:reminder];
    }
    
    if (recurrence && recurrence != (id)[NSNull null]) {
        EKRecurrenceRule *rule = [[EKRecurrenceRule alloc] initRecurrenceWithFrequency: [self toEKRecurrenceFrequency:recurrence]
                                                                              interval: 1
                                                                                   end: nil];
        if (recurrenceEndTime && recurrenceEndTime != nil) {
            NSTimeInterval _recurrenceEndTimeInterval = [recurrenceEndTime doubleValue] / 1000; // strip millis
            NSDate *myRecurrenceEndDate = [NSDate dateWithTimeIntervalSince1970:_recurrenceEndTimeInterval];
            EKRecurrenceEnd *end = [EKRecurrenceEnd recurrenceEndWithEndDate:myRecurrenceEndDate];
            rule.recurrenceEnd = end;
        }
        [event addRecurrenceRule:rule];
    }
    
    // Now save the new details back to the store
    NSError *error = nil;
    [self.eventStore saveEvent:event span:EKSpanThisEvent error:&error];
    
    // Check error code + return result
    if (error) {
        return [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.userInfo.description];
        
    } else {
        return [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        
    }
    
    

}


- (CDVPluginResult*)findAndDeleteEventsWithOptions:(NSDictionary*)options
                       inCalendar: (EKCalendar *) calendar {

    NSArray *matchingEvents = [self findEKEventsWithOptions:options andCalendar:calendar];
    
    NSError *error = NULL;
    for (EKEvent * event in matchingEvents) {
        [self.eventStore removeEvent:event span:EKSpanThisEvent error:&error];
    }
    
    CDVPluginResult *pluginResult;
    if (error) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.userInfo.description];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    }
    
    return pluginResult;
}

-(NSArray*)findEKEventsWithTitle: (NSString *)title
                        location: (NSString *)location
                           notes: (NSString *)notes
                       startDate: (NSDate *)startDate
                         endDate: (NSDate *)endDate
                        calendar: (EKCalendar *) calendar {
    
    // Build up a predicateString - this means we only query a parameter if we actually had a value in it
    NSMutableString *predicateString= [[NSMutableString alloc] initWithString:@""];
    if (title != (id)[NSNull null] && title.length > 0) {
        [predicateString appendString:[NSString stringWithFormat:@"title == '%@'", title]];
    }
    if (location != (id)[NSNull null] && location.length > 0) {
        [predicateString appendString:[NSString stringWithFormat:@" AND location == '%@'", location]];
    }
    if (notes != (id)[NSNull null] && notes.length > 0) {
        [predicateString appendString:[NSString stringWithFormat:@" AND notes == '%@'", notes]];
    }
    
    NSPredicate *matches = [NSPredicate predicateWithFormat:predicateString];
    
    NSArray *calendarArray = [NSArray arrayWithObject:calendar];
    
    NSArray *datedEvents = [self.eventStore eventsMatchingPredicate:[eventStore predicateForEventsWithStartDate:startDate endDate:endDate calendars:calendarArray]];
    
    NSArray *matchingEvents = [datedEvents filteredArrayUsingPredicate:matches];
    
    return matchingEvents;
}

-(NSArray*)findEKEventsWithOptions:(NSDictionary*)options andCalendar:(EKCalendar*)calendar {

    NSString* title      = [options objectForKey:@"title"];
    NSString* location   = [options objectForKey:@"location"];
    NSString* notes      = [options objectForKey:@"notes"];
    NSNumber
        *start  = [options objectForKey:@"startTime"],
        *end    = [options objectForKey:@"endTime"];
    
    NSDate
        *startDate = [self dateFromUnixOffset:start],
        *endDate = [self dateFromUnixOffset:end];
    
    
    return [self findEKEventsWithTitle:title location:location notes:notes startDate:startDate endDate:endDate calendar:calendar];
}

-(EKCalendar*)findEKCalendar: (NSString *)calendarName {
    for (EKCalendar *thisCalendar in [self.eventStore calendarsForEntityType:EKEntityTypeEvent]){
        NSLog(@"Calendar: %@", thisCalendar.title);
        if ([thisCalendar.title isEqualToString:calendarName]) {
            return thisCalendar;
        }
    }
    NSLog(@"No match found for calendar with name: %@", calendarName);
    return nil;
}

-(EKSource*)findEKSource {
    // if iCloud is on, it hides the local calendars, so check for iCloud first
    for (EKSource *source in self.eventStore.sources) {
        if (source.sourceType == EKSourceTypeCalDAV && [source.title isEqualToString:@"iCloud"]) {
            return source;
        }
    }
    
    // ok, not found.. so it's a local calendar
    for (EKSource *source in self.eventStore.sources) {
        if (source.sourceType == EKSourceTypeLocal) {
            return source;
        }
    }
    return nil;
}

#pragma mark Cordova functions

#pragma mark Calendar

- (void)listCalendars:(CDVInvokedUrlCommand*)command {

    [self.commandDelegate runInBackground:^{

        NSArray *calendars = [self.eventStore calendarsForEntityType:EKEntityTypeEvent];
        // TODO when iOS 5 support is no longer needed, change the line above by the line below (and a few other places as well)
        // NSArray * calendars = [self.eventStore calendarsForEntityType:EKEntityTypeEvent];
        
        NSMutableArray *finalResults = [[NSMutableArray alloc] initWithCapacity:calendars.count];
        for (EKCalendar *calendar in calendars){
            [finalResults addObject:[self calendarToDict:calendar]];
        }
        
        CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK messageAsArray:finalResults];

        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }];
}

-(void)getCalendarWithId:(CDVInvokedUrlCommand *)command {
    
    [self.commandDelegate runInBackground:^{
    
        NSString* calendarId = [command.arguments objectAtIndex:0];
        
        EKCalendar *calendar = [self calendarWithId:calendarId];
        
        CDVPluginResult *result;
        if(calendar) {
            NSDictionary *calendarDict = [self calendarToDict:calendar];
            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:calendarDict];
        }
        else {
            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Couldn't get calendar with id"];
        }
        
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }];
}

-(void)saveCalendar:(CDVInvokedUrlCommand*)command {
    
    [self.commandDelegate runInBackground:^{
        
        NSDictionary* options = [command.arguments objectAtIndex:0];
        NSString* calendarName = [options objectForKey:@"calendarName"];
        NSString* hexColor = [options objectForKey:@"calendarColor"];
        
        CDVPluginResult *result;
        
        EKCalendar *cal = [self findEKCalendar:calendarName];
        if (cal == nil) {
            cal = [EKCalendar calendarWithEventStore:self.eventStore];
            cal.title = calendarName;
            if (hexColor != (id)[NSNull null]) {
                UIColor *theColor = [self colorFromHexString:hexColor];
                cal.CGColor = theColor.CGColor;
            }
            cal.source = [self findEKSource];
            
            // if the user did not allow permission to access the calendar, the error Object will be filled
            NSError* error;
            [self.eventStore saveCalendar:cal commit:YES error:&error];
            if (error == nil) {
                NSLog(@"created calendar: %@", cal.title);
                result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
            } else {
                NSLog(@"could not create calendar, error: %@", error.description);
                result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Calendar could not be created. Is access to the Calendar blocked for this app?"];
            }
            
        } else {
            // ok, it already exists
            result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK messageAsString:@"OK, Calendar already exists"];
        }
        
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }];
    
    
    
}

-(void)deleteCalendarWithId:(CDVInvokedUrlCommand*)command {
    
    [self.commandDelegate runInBackground:^{
        
        NSString* calendarId = [command.arguments objectAtIndex:0];

        EKCalendar *calendar = [self.eventStore calendarWithIdentifier:calendarId];
        
        CDVPluginResult *result;
        if (calendar == nil) {
            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
        } else {
            
            NSError *error;
            [eventStore removeCalendar:calendar commit:YES error:&error];
            
            if (error) {
                NSLog(@"Error in deleteCalendar: %@", error.localizedDescription);
                result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.userInfo.description];
            } else {
                NSLog(@"Deleted calendar: %@", calendar.title);
                result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
            }
        }
        
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }];
    
    
}

#pragma mark Event

- (void)listEvents:(CDVInvokedUrlCommand*)command {
    
    [self.commandDelegate runInBackground:^{
        
        NSDictionary* options = [command.arguments objectAtIndex:0];
        
        NSNumber
            *start  = [options objectForKey:@"startTime"],
            *end    = [options objectForKey:@"endTime"];
        
        NSArray* calendarIds  = [options objectForKey:@"calendarIds"];
        
        NSDate *startDate, *endDate;
        
        if(start && end && ![start isEqual:[NSNull null]] && ![end isEqual:[NSNull null]]) {
            
            startDate = [self dateFromUnixOffset:start],
            endDate = [self dateFromUnixOffset:end];
        }
        else {
            const double secondsInAYear = (60.0*60.0*24.0)*365.0;
            startDate = [NSDate dateWithTimeIntervalSinceNow:-2*secondsInAYear];
            endDate = [NSDate dateWithTimeIntervalSinceNow:2*secondsInAYear];
            
            //Bug where can only fetch events from 4 years
            //startDate = [NSDate distantPast];
            //endDate = [NSDate distantFuture];
        }
        
        
        NSArray *calendars;
        if(calendarIds)
            calendars = [self calendarsFromIds:calendarIds];
        
        NSPredicate *predicate = [self.eventStore predicateForEventsWithStartDate:startDate endDate:endDate calendars:calendars];
        
        NSArray *events = [self.eventStore eventsMatchingPredicate:predicate];
        
        NSArray *formattedEvents = [self eventsToDicts:events];
        
        CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK messageAsArray:formattedEvents];
        
        // The sendPluginResult method is thread-safe.
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }];
    
}

-(void)getEventWithId:(CDVInvokedUrlCommand*)command {
    
    [self.commandDelegate runInBackground:^{
        
        NSString* eventIdentifier = [command.arguments objectAtIndex:0];
        
        EKEvent *event = [self.eventStore eventWithIdentifier:eventIdentifier];
        
        CDVPluginResult *result;
        if (event) {
            NSDictionary *eventDict = [self eventToDict:event];
            result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK messageAsDictionary:eventDict];
        } else {
            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Couldn't get event with id"];
        }
        
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }];
    
}

- (void)saveEvent:(CDVInvokedUrlCommand*)command {
    
    [self.commandDelegate runInBackground:^{
        
        NSDictionary *eventDict = [command.arguments objectAtIndex:0];
        NSString *eventId = [eventDict objectForKey:@"id"];
        
        EKEvent *event = [self.eventStore eventWithIdentifier:eventId];
        
        if(!event) {
            //Assume creating event
            event = [EKEvent eventWithEventStore:self.eventStore];
        }
        
        CDVPluginResult *pluginResult = [self modifyEvent:event withOptions:eventDict];
        
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
    
}

-(void)deleteEventWithId:(CDVInvokedUrlCommand*)command {
    
    [self.commandDelegate runInBackground:^{

        NSString* eventId = [command.arguments objectAtIndex:0];
        EKEvent *event = [self.eventStore eventWithIdentifier:eventId];
    
        NSError* error;
        [self.eventStore removeEvent:event span:EKSpanThisEvent error:&error];
    
        CDVPluginResult *result;
        if (error) {
            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.userInfo.description];
        } else {
            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        }
    
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        
    }];
}

-(void)findMatchingEvents:(CDVInvokedUrlCommand*)command {
    
    [self.commandDelegate runInBackground:^{
        
        EKCalendar* calendar = self.eventStore.defaultCalendarForNewEvents;
        
        CDVPluginResult* result;
        
        if (calendar == nil) {
            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No default calendar found. Is access to the Calendar blocked for this app?"];
        } else {
            
            NSDictionary* options = [command.arguments objectAtIndex:0];
            NSArray *matchingEvents = [self findEKEventsWithOptions:options andCalendar:calendar];
            
            NSMutableArray *finalResults = [self eventsToDicts:matchingEvents];
            
            result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK messageAsArray:finalResults];
            
        }
        
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }];
    
    
}

-(void)deleteMatchingEvents:(CDVInvokedUrlCommand*)command {
    
    [self.commandDelegate runInBackground:^{
        
        NSDictionary* options = [command.arguments objectAtIndex:0];
        EKCalendar* calendar = self.eventStore.defaultCalendarForNewEvents;
        
        CDVPluginResult *result;
        if (calendar == nil) {
            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No default calendar found. Is access to the Calendar blocked for this app?"];
            
        } else {
            result = [self findAndDeleteEventsWithOptions:options inCalendar:calendar];
        }
        
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }];
    

}


@end
