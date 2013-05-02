# Trackoid

> Trackoid is an analytics tracking system made specifically for MongoDB using Mongoid as ORM.

[![Build Status](https://travis-ci.org/twoixter/trackoid.png)](https://travis-ci.org/twoixter/trackoid)

## IMPORTANT upgrade information

**Trackoid Version 0.4.0** is updated to work with Mongoid 3. It's NOT backwards compatible with any previous version of Mongoid. A dependency on Ruby 1.9.x has also been added.

**Trackoid Version 0.3.0** changes the internal representation of tracking data. So **YOU WILL NOT SEE PREVIOUS DATA** when you update.

Hopefully, due to the magic of MongoDB, data is **NOT LOST**. In fact it's never lost unless you delete it. :-) _Just it's not visible right away_.

See **Changes for TZ support** below for an explanation of changes in the internal representation of tracked data.

### Should I 'lock' the Trackoid version with Bundler?

If you are new to Trackoid and don't know what I'm talking about **you're safe** upgrading from 0.4.x onwards.

If you are having problems with Ruby 1.9.3 or not using Mongoid 3.x, probably you'll want to lock on 0.3.x, since 0.4.x *requires Mongoid 3.x** and hence, requires Ruby 1.9.3+.


# Requirements

Trackoid requires Mongoid, which obviously in turn requires MongoDB. Although you can only use Trackoid in Rails projects using Mongoid, it can easily be ported to MongoMapper or other ORM. You can also port it to work directly using MongoDB.

Please feel free to fork and port to other libraries. However, Trackoid really requires MongoDB since it is build from scratch to take advantage of several MongoDB features (please let me know if you dare enough to port Trackoid into CouchDB or similar, I will be glad to know).

# Using Trackoid to track analytics information for models

Given the most obvious use for Trackoid, consider this example:

    Class WebPage
      include Mongoid::Document
      include Mongoid::Tracking

      ...

      track :visits
    end

This class models a web page, and by using `track :visits` we add a `visits` field to track... well... visits. :-) Later, in out controller we can do:

    def view
      @page = WebPage.find(params[:webpage_id])

      @page.visits.inc  # Increment a visit to this page
    end

That is, dead simple. Later in our views we can use the `visits` field to show the visit information to the users:

    <h1><%= @page.visits.today %> visits to this page today</h1>
    <p>The page had <%= @page.visits.yesterday %> visits yesterday</p>

Of course, you can also show visits in a time range:

    <h1>Visits on last 7 days</h1>
    <ul>
      <% @page.visits.last_days(7).reverse.each_with_index do |d, i| %>
      <li><%= (DateTime.now - i).to_s %> : <%= d %></li>
      <% end %>
    </ul>

## Not only visits...

Of course, you can use Trackoid to track all actions who require numeric analytics in a date frame.

### Prevent login to a control panel with a maximum login attemps

You can track invalid logins so you can prevent login for a user when certain invalid login had been made. Imagine your login controller:

    # User model
    class User
      include Mongoid::Document
      include Mongoid::Tracking

      track :failed_logins
    end

    # User controller
    def login
      user = User.find(params[:email])

      # Stop login if failed attemps > 3
      redirect(root_path) if user.failed_logins.today > 3

      # Continue with the normal login steps
      if user.authenticate(params[:password])
        redirect_back_or_default(root_path)
      else
        user.failed_logins.inc
      end
    end

Note that additionally you have the full failed login history for free. :-)

    # All failed login attemps, ever.
    @user.failed_logins.sum

    # Failed logins this month.
    @user.failed_logins.this_month


### Automatically saving a history of document changes

You can combine Trackoid with the power of callbacks to automatically track certain operations, for example modification of a document. This way you have a history of document changes.

    class User
      include Mongoid::Document
      include Mongoid::Tracking

      field :name
      track :changes

      after_update :track_changes

      protected
      def track_changes
        self.changes.inc
      end
    end


### Track temperature history for a nuclear plant

Imagine you need a web service to track the temperature of all rooms of a nuclear plant. Now you have a simple method to do this:

    # Room temperature
    class Room
      include Mongoid::Document
      include Mongoid::Tracking

      track :temperature
    end


    # Temperature controller
    def set_temperature_for_room
      @room = Room.find(params[:room_number])

      @room.temperature.set(current_temperature)
    end

So, you are not restricted into incrementing or decrementing a value, you can also store an specific value. Now it's easy to know the maximum temperature of the last 30 days for a room:

    @room.temperature.last_days(30).max


# How does it works?

Trakoid works by embedding date tracking information into the models. The date tracking information is limited by a granularity of days, but you can use aggregates if you absolutely need hour or minutes granularity.


## Scalability and performance

Trackoid is made from the ground up to take advantage of the great scalability features of MongoDB. Trackoid uses "upsert" operations, bypassing Mongoid controllers so that it can be used in a distributed system without data loss. This is perfect for a cloud hosted SaaS application!

The problem with a distributed system for tracking analytical information is the atomicity of operations. Imagine you must increment visits information from several servers at the same time and how you would do it. With an SQL model, this is somewhat easy because the tradittional approaches for doing this only require INSERT or UPDATE operations that are atomic by nature. But for a Document Oriented Database like MongoDB you need some kind of special operations. MongoDB uses "upsert" commands, which stands for "update or insert". That is, modify this and create if not exists.

The problem with Mongoid, and with all other ORM for that matter, is that they are not made with those operations in mind. If you store an Array or Hash into a Mongoid document, you read or save it as a whole, you can not increment or store only a value without reading/writting the full Array.

Trackoid issues "upsert" commands directly to the MongoDB driver, with the following structure:


  collection.update( {_id:ObjectID}, {$inc: {visits.2010.05.30: 1} }, true )


This way, the collection can receive multiple incremental operations without requiring additional logic for locking or something. The only drawback is that you will not have realtime data in your model. For example:

  v = @page.visits.today      # v is now "5" if there was 5 visits today
  @page.visits.inc            # Increment visits today
  @page.visits.today == v+1   # Visits is now incremented in our local copy
                              # of the object, but we need to reload for it
                              # to reflect the realtime visits to the page
                              # since there could be another processes
                              # updating visits

In practice, we don't need visits information so fine grained, but it's good to take this into account.

## Embedding tracking information into models

Tracking analytics data in SQL databases was historicaly saved into her own table, perhaps called `site_visits` with a relation to the sites table and each row saving an integer for each day.

    Table "site_visits"

    SiteID  Date        Visits
    ------  ----------  ------
    1234    2010-05-01  34
    1234    2010-05-02  25
    1234    2010-05-03  45

With this schema, it's easy to get visits for a website using single SQL statements. However, for complex queries this can be easily become cumbersome. Also this doesn't work so well for systems using a generic SQL DSL like ActiveRecord since for really taking advantage of some queries you need to use SQL language directly, one option that isn't neither really interesting nor available.

Trackoid uses an embedding approach to tackle this. For the above examples, Trackoid would embedd a ruby Hash into the Site model. This means the tracking information is already saved "inside" the Site, and we don't have to reach the database for any date querying! Moreover, since the data retrieved with the accessor methods like "last_days", "this_month" and the like, are already arrays, we could use Array methods like sum, count, max, min, etc...

## Memory implications

Since storing all tracking information with the model implies we add additional information that can grow, and grow, and grow... You can be wondering yourself if this is a good idea. Yes, it's is, or at least I think so. Let me convice you...

MongoDB stores information in BSON format as a binary representation of a JSON structure. So, BSON stores integers like integers, not like string representations of ASCII characters. This is important to calculate the space used for analytic information.

A year full of statistical data takes only 2.8Kb, if you store integers. If your statistical data includes floats, a year full of information takes 4.3Kb. I said "a year full of data" because Trackoid does not store information for days without data.

For comparison, this README is already 8.5Kb in size...


# Changes for TZ support

Well, this is the time (no pun intended) to add TZ support to Trackoid.

The problem is that "today" is not the same "today" for everyone, so unless you live in UTC or don't care about time zones, you probably should stay in 0.2.0 version and live long and prosper...

But... Okay, given the fact that "today" is not the same "today" for everyone, this is the brand new Trackoid, with TZ support.

## What has changed?

In the surface, almost nothing, but internally there has been a major rewrite of the tracking code (the 'inc', 'set' methods) and the readers ('today', 'yesterday', etc). This is due to the changes I've made to the MongoDB structure of the tracking data.

<b>YOU WILL NEED TO MIGRATE THE EXISTING DATA IF YOU WANT TO KEEP IT</b>

This is very important, so I will repeat:

<b>YOU WILL NEED TO MIGRATE THE EXISTING DATA IF YOU WANT TO KEEP IT</b>

The internal JSON structure of a tracking field was like that.

    {
      ... some other fields in the model...,
      "tracking_data" : {
        "2011" : {
          "01" : {
            "01" : 10,
            "02" : 20,
            "03" : 30,
            ...
          },
          "02" : {
            "01" : 10,
            "02" : 20,
            "03" : 30,
            ...
          }
        }
      }
    }

That is, years, months and days numbers created a nested hash in which the final data (leaves) was the amount tracked. You see? There was no trace of hours... That's the problem.

This is the new, TZ aware version of the internal JSON structure:

    {
      ... some other fields in the model...,
      "tracking_data" : {
        "14975" : {
          "00" : 10,
          "01" : 20,
          "02" : 30,
          ...
          "22" : 88,
          "23" : 99
        },
        "14976" : {
          "00" : 10,
          "01" : 20,
          "02" : 30,
          ...
          "22" : 88,
          "23" : 99
        }
      }
    }

So, instead of a nested array with keys like year/month/day, I now use the timestamp of the date. Well, a cooked timestamp. "14975" is the numbers of days since the epoch, which is the number of seconds elapsed since midnight Coordinated Universal Time (UTC) of January 1, 1970, and blah, blah, blah... You know what's this all about (http://en.wikipedia.org/wiki/Unix_time)

The exact formula is like this (Ruby):

    date_index = Time.now.utc.to_i / 60 / 60 / 24

The contents of every "day record" is another hash with 24 keys, one for each hour. This MUST be a hash, not an array (which might be more natural) sice Trackoid uses "upserts" operations to be atomic. Reading the array, modifying it and saving it back is not an option. The exact MongoDB operation to support this is as follows:

    db.update(
      { search_criteria },
      { "$inc" => {"track_data.14976.10" => 1} },
      { :upsert => true, :safe => false }
    )

## What "today" is it?

All dates are saved in UTC. That means Trackoid returns a whole 24 hour block for "today" only where the TZ is exactly UTC/GMT (no offset). If you live in a country where there is an offset into UTC, Trackoid must read a whole block and some hours from the block before or after to build "your today".

Example: I live in GMT+0200 (Daylight saving in effect, or summer time), then if I request data for "today" as of 2011-04-14, Trackoid must first read the block for 15078 (UTC index for 2011-04-14), shift up 2 hours and then fill the missing 2 hours from the day before (15078). The entire block will be like this:

    "tracking_data" : {
      "15078" : {
        "22" : 88,    # Last two hours from 2011-04-13 UTC
        "23" : 99
      },
      "15079" : {
        "00" : 10,
        "01" : 20,
        "02" : 30,
        ""
      }

This is a more graphical representation:

    Hours  00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23
    ------ -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
    GMT+2: 00 00 00 XX 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
      UTC: --->  00 XX 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
           Shift up ---> 2 hours.


For timezones with a negative offset from UTC (Like PDT/PST) the process is reversed: UTC values are shifted down and holes filled with the following day.


## How should I tell Trackoid how TZ to use?

Piece of cake: Use the reader methods "today", "yesterday", "last_days(N)" and Trackoid will use the effective Time Zone of your Rails/Ruby application.

Trackoid will correctly translate dates for you (hopefully) if you pass a date to any of those methods.



# Revision History
  0.3.8  - Fixed support for Ruby 1.9.3

  0.3.7  - Fixed support for Rails 3.1 and Mongoid 2.2

  0.3.6  - Optimization for 'on' reader for ranges. Many times fold quicker.

  0.3.5  - BUGFIX: ReaderExtender "+" acted like an accumulator. Problem more
           evident when using ActiveSupport "sum" for arrays.

  0.3.4  - BUGFIX: Fixed midnight calculation for Time.whole_day

  0.3.3  - as_json should take a "options" hash as optional parameter.

  0.3.2  - ReaderExtender as_json sould not return the full "total" and
           "hours" data. I think it's more reasonable to return just the
           total number like it always was. If you have the whole structure
           you need to add somewhere:

           def as_json
             { :total => @stat, :hourly => @stat.hourly }
           end

  0.3.1  - Implemented 'to_f' into ReaderExtender to be compatible with
           ActionView::Template
           Using "%.1f" % number gave "Can't convert to float"

         - Renamed the internal field of ReaderExtender to "total" so that
           converting to json automatically gives you:

           {
             "total": <total value>
             "hours": [<hours array>]
           }

  0.3.0  -  Biggest change ever. Read <b>Changes for TZ support</b> above.
            <b>YOU WILL NEED A MIGRATION FOR EXISTING DATA</b>

  ------

  0.2.0  -  Added 'reset' and 'erase' methods to tracker fields:
            * Reset does the same as "set" but also sets aggregate fields.

              Example:

                A) model.value(aggregate_data).set(5)
                B) model.value(aggregate_data).reset(5)

                A will set "5" to the 'value' and to the aggregate.
                B will set "5" to the 'value' and all aggregates.

            * Erase resets the values in the mongo database. Note that this
              is completely different of doing 'reset(0)'. (With erase you
              can actually recall space from the database).

         -  Trackoid now uses "unsafe" mongo update calls from the driver.
            Note that despite the name, trackoid is absolutely safe, the only
            diference is that 'update' simply now returns inmediately, without
            waiting for the OK response from the database.

  0.1.12 -  Previously known as "accessors" methods, now they are promoted as
            "Reader" methods and now they live in its own Module.
            (Accessor methods are those like "today", "on", "last_days", etc,
            and now they are called "Readers" to avoid confussion with real
            accessors like "attr_accessors"...)

  0.1.11 -  Updated Gemspec for a new version of Jeweler

  0.1.10 -  Renamed accessor methods from "all", "last", "first" to
            "all_values", "first_value" and "last_value" so as not to
            conflict with traditional ActiveRecord accessors.

         -  Aggregate methods with a key returns a single instance, not an
            Array. For example:

              @page.visits.browser("mozilla").today
              # Returns now a number instead of an Array

         -  Arguments are now passed thru aggregator accessors. For example:

              @page.visits.brosers("mozilla").last_days(15)
              # Should correctly return now an array with 15 elements.

  0.1.9  -  Refactored TrackerAggregates to include all accessor methods
            (all, last, first, etc.)

  0.1.8  -  Another maintenance release. Sorry. :-)

  0.1.7  -  Maintenance Release: A little error with the index on aggregated
            fields

  0.1.6  -  Enabled support for String dates in operators. This string date
            must be DateTime parseable.

            Example:

              @spain.world_cups.inc("2010-07-11")

         -  Normalized Date and DateTime objects to use only Date methods.
         -  Added "first" / "first_date" / "last" / "last_date" accessors.
         -  Added "all" accessor.

  0.1.5  -  Added support for namespaced models and aggregations
         -  Enabled "set" operations on aggregates
