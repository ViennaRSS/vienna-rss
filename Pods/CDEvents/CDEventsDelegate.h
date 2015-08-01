/**
 * CDEvents
 *
 * Copyright (c) 2010-2013 Aron Cedercrantz
 * http://github.com/rastersize/CDEvents/
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

/**
 * @headerfile CDEventsDelegate.h CDEvents/CDEventsDelegate.h

 * 
 * A protocol that that delegates of CDEvents conform to. Inspired and based
 * upon the open source project SCEvents created by Stuart Connolly
 * http://stuconnolly.com/projects/code/
 */

@class CDEvents;
@class CDEvent;


/**
 * The CDEventsDelegate protocol defines the required methods implemented by delegates of CDEvents objects.
 *
 * @see CDEvents
 * @see CDEvent
 *
 * @since 1.0.0
 */
@protocol CDEventsDelegate

@required
/**
 * The method called by the <code>CDEvents</code> object on its delegate object.
 *
 * @param URLWatcher The <code>CDEvents</code> object which the event was recieved thru.
 * @param event The event data.
 *
 * @see CDEvents
 * @see CDEvent
 *
 * @discussion Conforming objects' implementation of this method will be called
 * whenever an event occurs. The instance of CDEvents which received the event
 * and the event itself are passed as parameters.
 *
 * @since 1.0.0
 */
- (void)URLWatcher:(CDEvents *)URLWatcher eventOccurred:(CDEvent *)event;

@end

