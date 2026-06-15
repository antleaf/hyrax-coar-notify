# Hyrax Notify

## with an external COAR Notify inbox service



by 



**Anusha Ranganathan**

**Cottage Labs**

<div style="page-break-after: always; break-after: page;"></div>

## Introduction

The Hyrax COAR Notify application is an application based on [Samvera Hyrax (v5.2)](https://github.com/samvera/hyrax) with an integrated COAR Notify service, enabling the application to send and receive COAR Notify messages, in accordance with the [COAR Notify Protocol (v1.0.1)](https://coar-notify.net/specification/1.0.1/).

Hyrax COAR Notify receives incoming COAR Notify messages from an external inbox service and is registered with a peer review service - [Peer Community In (PCI)](https://coar-notify.net/catalogue/implementations/service-instances/pci/).

The external inbox is provided by the [COAR-Notify Inbox rails engine](https://github.com/antleaf/coar-notify-inbox-rails-engine). This service receives COAR Notify messages from external systems (for example Peer Community In and makes them available for processing to Hyrax Notify. The [Notify inbox test application](https://github.com/antleaf/coar-notify-inbox-rails-engine/tree/test-app-docker/.notify_inbox_test) developed as a part of the COAR-Notify Inbox rails engine is deployed as a sand alone service and is setup with an admin user, as documented in the notify_inbox_test [README](https://github.com/antleaf/coar-notify-inbox-rails-engine/blob/main/.notify_inbox_test/README.md).

Hyrax Notify will support the following two workflows for COAR Notify

[Repository announces relationship workflow](#COAR-Notif---Repository-announces-relationship-workflow)

[PCI endorsement workflow](#COAR-Notify---PCI-endorsement-workflow)

<div style="page-break-after: always; break-after: page;"></div>

## COAR Notify - Repository announces relationship workflow 

Reference: https://coar-notify.net/catalogue/workflows/repository-relationship-repository/

![COAR Notify - Relationship workflow](Hyrax%20notify%20with%20external%20inbox%20images/COAR%20Notify%20-%20Relationship%20workflow.png)

<div style="page-break-after: always; break-after: page;"></div>

## COAR Notify - PCI endorsement workflow 

Reference: https://coar-notify.net/catalogue/workflows/repository-pci/

![COAR Notify - PCI Endorsement workflow](Hyrax%20notify%20with%20external%20inbox%20images/COAR%20Notify%20-%20PCI%20Endorsement%20workflow.png)

<div style="page-break-after: always; break-after: page;"></div>

## Step 1 - Setup COAR Notify inbox

### 1A - Create a user for the PCI service

The admin user for the COAR Notify inbox service needs to create a user for the PCI service, as shown below, and share the auth_token with PCI.

![Notify Inbox - create PCI user](Hyrax%20notify%20with%20external%20inbox%20images/Notify%20Inbox%20-%20create%20PCI%20user.png)

```
curl -X POST <coar_notify_inbox_service_url>/users \
  -H "Authorization: Bearer <admin_user_auth_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "name": “<PCI user display name>",
      "username": “<PCI user username>",
      "role": "user",
      "active": true
    }
  }'
```

<div style="page-break-after: always; break-after: page;"></div>

### 1B - Add senders for the PCI service

Either the admin user for the COAR Notify inbox service or the PCI user needs to create senders, one for each URI from which notifications will originate from PCI.

**NOTE: If the PCI user creates a sender, the sender needs to be activated by the inbox admin user**

![Notify Inbox - register sender](Hyrax%20notify%20with%20external%20inbox%20images/Notify%20Inbox%20-%20register%20sender.png)

```
curl -s -X POST <coar_notify_inbox_service_url>/senders \
  -H "Authorization: Bearer <admin_user_auth_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "username": “<PCI user username>",
    "origin_uri": “<URI from which requests will originate in PCI>",
    "target_uris": [“<URI of consumer of the message>, <"Hyrax notify URI"],
    "sender": {"active": true}
  }' | jq .
```

<div style="page-break-after: always; break-after: page;"></div>

### 1C - Create a user for the Hyrax Notify service

The admin user for the COAR Notify inbox service needs to create a user for the Hyrax Notify service, as shown below, and share the auth_token with Hyrax Notify.

![Notify Inbox - create Hyrax Notify user](Hyrax%20notify%20with%20external%20inbox%20images/Notify%20Inbox%20-%20create%20Hyrax%20Notify%20user.png)

```
curl -X POST <coar_notify_inbox_service_url>/users \
  -H "Authorization: Bearer <admin_user_auth_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "name": “<Hyrax user display name>",
      "username": “<Hyrax user username>",
      "role": "user",
      "active": true
    }
  }'
```

<div style="page-break-after: always; break-after: page;"></div>

## Step 2 - Create a role and users in the Hyrax Notify application

Create a role in Hyrax Notify to manage the COAR Notify services and add users to the role. The user role to be used for the *Hyrax Notify service manager* is defined in the `.env` file

```
# .env
NOTIFY_MANAGER_ROLE = admin
```

If a role other than admin is used, the role will need to be created by an admin user within the Hyrax COAR Notify application.

![Hyrax Notify - add role and create users](Hyrax%20notify%20with%20external%20inbox%20images/Hyrax%20Notify%20-%20add%20role%20and%20create%20users.png)

<div style="page-break-after: always; break-after: page;"></div>

## Step 3 - Hyrax Notify - Notify dashboard

Login as the user with the *NOTIFY_MANAGER_ROLE.* The *Notify dashboard* should be visible to you, as shown below.

In order to start receiving and sending messages from/to COAR Notify enabled services, we need to add 

* one or more services to which we send messages, and 
* one or more inboxes, from which we will receive messages.

This is done by clicking on *Manage Notify Connections*.

![Hyrax Notify - Notify dashboard](Hyrax%20notify%20with%20external%20inbox%20images/Hyrax%20Notify%20-%20Notify%20dashboard.png)

<div style="page-break-after: always; break-after: page;"></div>

## Step 4 - Hyrax Notify - Manage Notify connections

This dashboard is only visible to users with the role *NOTIFY_MANAGER_ROLE* or the admin user*.*

Here, we can view a list of all existing Notify related services connected with Hyrax Notify, manage the services and add new connections. 

Hyrax Notify will send messages to a Notify service, who will in turn send messages to an inbox, and Hyrax Notify will receive messages from the inbox.

![Hyrax Notify - manage Notify connections](Hyrax%20notify%20with%20external%20inbox%20images/Hyrax Notify%20-%20manage%20Notify%20connections.png)

<div style="page-break-after: always; break-after: page;"></div>

### 4A - Register a Notify inbox

Before we can receive COAR notify messages, we need to connect to a Notify inbox. 

In [step Ic](#1C---Create-a-user-for-the-Hyrax-Notify-service), we created a user for Hyrax Notify in the inbox and in response, received an auth token from the inbox, which we need to use to authenticate with the inbox.

To add a connection to the inbox, we need the URI endpoint for the inbox service and the auth token we had received earlier.

This step needs to be done by the user with the role *NOTIFY_MANAGER_ROLE* or an admin user*.*

![Hyrax Notify - register notify inbox](Hyrax%20notify%20with%20external%20inbox%20images/Hyrax%20Notify%20-%20register%20notify%20inbox.png)

<div style="page-break-after: always; break-after: page;"></div>

### 4B - Register a Notify service

Before we can send COAR notify messages to a review service or repository,, we need to connect to the service.. 

To add a connection to the service, we need the URI endpoint for the review service, an API key (auth token) to authenticate with the service, and a list of URIs from which notifications will originate.

This step needs to be done by the user with the role *NOTIFY_MANAGER_ROLE* or an admin user*.*

![Hyrax Notify - register Notify service](Hyrax%20notify%20with%20external%20inbox%20images/Hyrax%20Notify%20-%20register%20Notify%20service.png)

<div style="page-break-after: always; break-after: page;"></div>

### 4C - Add a consumer to the inbox

The service registered in the previous step will be sending messages to the inbox service we have signed up to in [step 1c](#1C---Create-a-user-for-the-Hyrax-Notify-service) and [step 4a](#4A---Register-a-Notify-inbox) and Hyrax Notify will get it’s messages from the inbox. In order to be able to link messages received from the review service or repository to Hyrax Notify, we need to be added as a consumer within the inbox.

To add a consumer within the inbox, we need the URI endpoint of Hyrax Notify and a list of URIs from which notifications will originate (as obtained in the previous [step 4b](#4B---Register-a-Notify-service)).

This step can be done by the hyrax notify user registered with the inbox ([step 1b)](#1B---Add-senders-for-the-PCI-service) or the admin user of the inbox. If using the Hyrax Notify user, we will need the auth token for the inbox (from [step 1c](#1C---Create-a-user-for-the-Hyrax-Notify-service)) to authenticate with the service, 

**NOTE: If the Hyrax Notify user creates a consumer, the consumer needs to be activated by the inbox admin user**

![Notify Inbox - register consumer](Hyrax%20notify%20with%20external%20inbox%20images/Notify%20Inbox%20-%20register%20consumer.png)

```
curl -s -X POST <coar_notify_inbox_service_url>/consumers \
  -H "Authorization: Bearer <admin_user_auth_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "username": “<Hyrax user username>",
    "target_uri": "<hyrax_notify_base_url>",
    "origin_uris": [“<URI of sender of the message>, <“PCI URI”>],
    “consumer": {"active": true}
  }' | jq .
```

<div style="page-break-after: always; break-after: page;"></div>

## Step 5 - Hyrax Notify - work view

The owner of a work has the ability to request an endorsement of the work and view all of the endorsements, reviews and relationships for by the work, received as COAR Notify notifications.

![Hyrax Notify - work view](Hyrax%20notify%20with%20external%20inbox%20images/Hyrax%20Notify%20-%20work%20view.png)

<div style="page-break-after: always; break-after: page;"></div>

### 5A - Request an endorsement or review for the work

The owner of a work has the ability to request an endorsement or a review of the work from their [work view](#Step-5---Hyrax-Notify---work-view) page. The owner can choose the service (from the list of available services) to send the request to.

On clicking on the button to make a request, a background job is created in Hyrax Notify, which will send a Notify notification to the chosen service. 

A notification is also sent to the user, indicating that the request has been sent. This will be visible in [users' notification dashboard](#Step-6---Hyrax-Notify---Users'-notification-dashboard).

#### Background job to request an endorsement or review

The background job to request an endorsement or review does the following

*  Create a [Notify notification payload](#Request-an-endorsement-or-review-job-payload) - [request endorsement payload](https://coar-notify.net/specification/1.0.1/request-endorsement/) or [request review payload](https://coar-notify.net/specification/1.0.1/request-review/)
* Send it to the chosen service - for example, send the request to PCI using PCI inbox URL and API key, from PCI service registered in step [4B - Register a Notify service](#4B---Register-a-Notify-service)
* Create a Hyrax notification for the user, indicating that the request has been sent, along with the response received from the service. This will be visible in [users' notification dashboard](#Step-6---Hyrax-Notify---Users'-notification-dashboard).
  * If the response is an [Un-processable Notification](https://coar-notify.net/specification/1.0.1/unprocessable/), this needs to be handled.

![Hyrax Notify - work - request endorsement-2](Hyrax%20notify%20with%20external%20inbox%20images/Hyrax%20Notify%20-%20work%20-%20request%20endorsement-2.png)

<div style="page-break-after: always; break-after: page;"></div>

#### Request an endorsement or review job payload

Hyrax Notify will create a [request endorsement payload](https://coar-notify.net/specification/1.0.1/request-endorsement/) or [request review payload](https://coar-notify.net/specification/1.0.1/request-review/), based on the type of request.

![Hyrax Notify - work - request endorsement payload](Hyrax%20notify%20with%20external%20inbox%20images/Hyrax%20Notify%20-%20work%20-%20request%20endorsement%20payload.png)

<div style="color: green; font-weight: bold">When the hyrax work has multiple files, we will add the link only to the doc, docx and pdf files</div>

<div style="page-break-after: always; break-after: page;"></div>

### 5B - Receive Notify notifications and create relationships

Hyrax Notify has a background job which will periodically get the list of notifications received in the inbox since the last run and each notification is processed.

For all the different COAR Notify notification types - [Accept a request](https://coar-notify.net/specification/1.0.1/accept/), [Reject a request](https://coar-notify.net/specification/1.0.1/reject/), [Tentatively Accept a request](https://coar-notify.net/specification/1.0.1/tentative-accept/), [Tentatively Reject a request](https://coar-notify.net/specification/1.0.1/tentative-reject/), [Announce Endorsement](https://coar-notify.net/specification/1.0.1/announce-endorsement/), [Announce Relationship](https://coar-notify.net/specification/1.0.1/announce-relationship/) and [Announce Review](https://coar-notify.net/specification/1.0.1/announce-review/) - a Hyrax Notify user notification is created to inform the user (actor) of the decision. This will be visible in the [users' notification dashboard](#Step-6---Hyrax-Notify---Users'-notification-dashboard).

In addition, for the announcement notifications - [Announce Endorsement](https://coar-notify.net/specification/1.0.1/announce-endorsement/), [Announce Relationship](https://coar-notify.net/specification/1.0.1/announce-relationship/) and [Announce Review](https://coar-notify.net/specification/1.0.1/announce-review/) - a relationship is created in the work for the endorsement, relationship or review. This is visible in the [work view](#Step-5---Hyrax-Notify---work-view) page. The owner of the work can delete the endorsement / review / relationship from their work, if desired.

<div style="color: red; font-weight: bold">Note:</div> 

When a user receives a COAR Notify notification of type [Tentatively Reject a request](https://coar-notify.net/specification/1.0.1/tentative-reject/), the reviewer typically requests changes to the work. For this use case, a new version of the work needs to be created, before submitting a review / endorsement again to the review service. . We need to send the link to the previous notification as in-reply. 

<div style="color: red; font-weight: bold">We need to decide how this should be implemented.</div>

<div style="page-break-after: always; break-after: page;"></div>

#### Background job to receive Notify notifications and create relationships

The background job to receive Notify notifications and create relationships does the following

1. Get a list of notification since the last run from the inbox

2. Process each notification, create a Hyrax Notify user notification, informing the user of the notification.

3. When the notification is an announcement notification, add a relationship in the work metadata.

   * If the work does not exist, create a Hyrax Notify user notification informing the user of the notification for the missing work.
   * If the actor does not exist, create a Hyrax Notify user notification informing the admin of the notification for the work.

   
   


![Hyrax Notify - work - receive notification and create relationships](Hyrax%20notify%20with%20external%20inbox%20images/Hyrax%20Notify%20-%20work%20-%20receive%20notification%20and%20create%20relationships.png)

<div style="page-break-after: always; break-after: page;"></div>

## Step 6 - Hyrax Notify - Users' notification dashboard

The Hyrax Notify users’ dashboard will have notification sent to the user by the Hyrax application, including COAR Notify notification messages, received by the [Receive Notify notifications and create relationships job](#5B---Receive-Notify-notifications-and-create-relationships-job).

![Hyrax Notify - user notifications dashboard](Hyrax%20notify%20with%20external%20inbox%20images/Hyrax%20Notify%20-%20user%20notifications%20dashboard.png)

<div style="page-break-after: always; break-after: page;"></div>

## Step 7 - Hyrax Notify - Messages in the [Notify dashboard](#Step-3---Hyrax-Notify---Notify-dashboard)

The Notify dashboard displays the latest notifications received by the Notify inbox before the last run (to only show processed messages).

### Get notifications for the [Notify dashboard](#Step-3---Hyrax-Notify---Notify-dashboard)

The notifications are obtained from the Notify Inbox, by making a HTTP request to `/notifications/consumer/<consumer_url>`

1. Define number of notifications to show in an ENV variable `hyrax_notify_notifications_limit`

2. Get a list of latest (*hyrax_notify_notifications_limit*) notifications received in the inbox (**before last run?**)

![Hyrax Notify - messages in the Notify dashboard-2](Hyrax%20notify%20with%20external%20inbox%20images/Hyrax%20Notify%20-%20messages%20in%20the%20Notify%20dashboard-2.png)

![Hyrax Notify - messages in the Notify dashboard-1](Hyrax%20notify%20with%20external%20inbox%20images/Hyrax%20Notify%20-%20messages%20in%20the%20Notify%20dashboard-1.png)
