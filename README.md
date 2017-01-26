# childprotect.com

Web service and API to consolidate and share information about abuse content on the web among cloud storage providers for instant reaction.


## ChildProtect API Documentation


### Synopsis

ChildProtect API is designed for developers of web services, mass file storage, file sharing and cloud hosting platforms. The idea of ChildProtect service is to consolidate and quickly synchronize among its members the information about abuse content uploaded on the web so that to be deleted instantly. The API provides methods for fetching lists of abuse tokens submitted within different periods, reporting deletion of particular content and publish tokens of newly discovered abuse content to be checked upon by all members.

Within various mass file storages a file may be referred to by its unique MD5 hash and its size in bytes. This compound footprint is also used to identify an abuse token within the ChildProtect database.


### Workflow

Following the best practices, an anti-abuse revision cycle performed by a file storage may look like this:
1. Aggregate the local list of abuse contents from abuse cases reported directly to the storage holder by third party organizations.
2. Decide on the list of files to be actually deleted in respect of local reports and commit the deletion.
3. Submit the resulting list of new abuse tokens to ChildProtect.
4. Request from ChildProtect an updated list of abuse tokens starting from the last revision period.
5. Decide on the list of files to be actually deleted in respect of updates received from ChildProtect and commit the deletion.
6. Report to ChildProtect the list of tokens deleted on step 5.

A passive revision cycle may look like this:
1. Request from ChildProtect an updated list of abuse tokens starting from the last revision period.
2. Decide on the list of files to be actually deleted in respect of updates received from ChildProtect and commit the deletion.
3. Report to ChildProtect the list of tokens deleted on step 2.

Only members of ChildProtect service are allowed to retrieve and submit abuse tokens. Any API request is a subject of authentication.


### Making requests to the API

The ChildProtect API is based on REST. The base URL prefix for the current REST API is

https://api.childprotect.com/REST/2/

Your user agent should use SSL 3.0 encryption. Should an API request (PUT, POST) or response contain a body, it has to be encoded or parsed as application/json.


### Methods of the REST API

ChildProtect REST API implements the following methods.


#### Submitting a single token

The footprint should be placed to the request URI in the form of MD5 and size parameters delimited by a colon.
```
PUT /REST/2/tokens/$md5:$fsize

Body: empty
```

Example: submit a single token for the file 2048 bytes long and the MD5 hash equal to 'ad0234829205b9033196ba818f7a872c'.
```
PUT /REST/2/tokens/ad0234829205b9033196ba818f7a872c:2048 HTTP/1.1
...
```

Return value is the same as for the corresponding bulk operation.
Resulting JSON example:
```
{
    "accepted": "1"
}
```


#### Submitting a list of new tokens

```
PUT /REST/2/tokens

Body: JSON structure
```

Example: submit 3 new tokens.
```
PUT /REST/2/tokens HTTP/1.1
...

{
    "tokens": [
        [ "5A105E8B9D40E1329780D62EA2265D8A", 3428632 ],
        [ "AD0234829205B9033196BA818F7A872B", 1024 ],
        [ "5A105E8B9D40E1329780D62EA2265D8B", 192262740 ]
    ]
}
```

Return value represents number of new and unique tokens accepted by ChildProtect.
Resulting JSON example:
```
{
    "accepted": "3"
}
```
The number of tokens accepted not always equal to the number of tokens submitted by client. For example, one or more of the tokens could not be accepted. The reason can be that the client have already reporded some of the tokens previously.


#### Reporting deletion of a specific token from the member's storage

The footprint should be placed to the request URI in the form of MD5 and size parameters delimited by a colon.
```
DELETE /REST/2/tokens/$md5:$fsize
```

Example: delete 1 token
```
DELETE /REST/2/tokens/ad0234829205b9033196ba818f7a872c:2048 HTTP/1.1
...
```

Return value represents number of tokens accepted for deletion.
Resulting JSON example:
```
{
    "accepted": "1"
}
```


#### Reporting deletion of multiple tokens from the member's storages

```
PUT /REST/2/tokens-deleted

Body: JSON structure
```

Example: report deletion of 5 tokens
```
PUT /REST/2/tokens-deleted HTTP/1.1
...

{
    "tokens": [
        [ "cd5386d30531904ae07eb7b006020630", 8719377433 ],
        [ "5A105E8B9D40E1329780D62EA2265D8A", 3428632 ],
        [ "AD0234829205B9033196BA818F7A872B", 1024 ],
        [ "5A105E8B9D40E1329780D62EA2265D8B", 192262740 ],
        [ "897d09da20bcc530dc91e1f1d460cdd2", 55602 ]
    ]
}
```

Return value represents number of tokens accepted for deletion.
Resulting JSON example:
```
{
    "accepted": "4"
}
```

In the example above one of the tokens was not accepted for deletion. The reason can be that the client have already reporded this token previously. So, the number of tokens accepted not always equal to the number of tokens submitted by client.


#### Getting foreign tokens submitted by other members and yet not being deleted by you
```
GET /REST/2/tokens?date1=YYYY-MM-DD&date2=YYYY-MM-DD
```

By default the list compiled will represent current tokens submitted during the current date. To specify other date periods, use respective query parameters - date1 and date2. One or both of the date ranges may be ommited. The date format is strict and should consist of 4 digits representing a year, 2-digit month and day of month, delimited by dashes ('YYYY-MM-DD').

Example: list foreign tokens for the period of 27-31 of May 2012
```
GET /REST/2/tokens?date1=2012-05-27&date2=2012-05-31 HTTP/1.1
...
```

Returned body contains list of tokens. Each token record contains an MD5 hash of submitted file, its size and the date when it was submitted to ChildProtect.

Resulting JSON example:
```
{
    "tokens": [
        [
            "5A105E8B9D40E1329780D62EA2265D8A",
            "3428632",
            "2012-06-03"
        ],
        [
            "AD0234829205B9033196BA818F7A872B",
            "1024",
            "2012-06-03"
        ]
    ]
}
```


#### Getting tokens submitted by user

The input formats and the return body structure are the same as in the previous method.
```
GET /REST/2/tokens-submitted?date1=YYYY-MM-DD&date2=YYYY-MM-DD
```


#### Getting tokens deleted by user

The input formats are the same as in the previous method.
```
GET /REST/2/tokens-deleted?date1=YYYY-MM-DD&date2=YYYY-MM-DD
```

Return body structure is the same as in the previous method except that the dates returned represent dates of deletion.


#### Getting counters

The counters represent your statistics on submitted and deleted tokens.
```
GET /REST/2/counters
```

Resulting JSON example:
```
{
    "submitted": "1828",
    "deleted": "7232"
}
```


### Authenticating Requests Using the REST API

When accessing ChildProtect API using REST, you must provide the following items in your request so the request can be authenticated:


##### Request Elements

* Access Key ID: An access key ID of the identity you are using to send your request.
* Signature: Each request must contain a valid request signature, or the request is rejected. A request signature is calculated using your Secret Access Key, which is a shared secret known only to you and ChildProtect.
* Date: Each request must contain the date and time the request was created, represented as a string in UTC.


Following are the general steps for authenticating requests to ChildProtect REST API. It is assumed you have the necessary security credentials, Access Key ID and Secret Access Key.

1. Construct a request to ChildProtect.
2. Calculate signature using your Secret Access Key.
3. Send the request to ChildProtect. Include your Access Key ID and the signature in your request. ChildProtect performs the next three steps.
4. ChildProtect uses the Access Key ID to look up your Secret Access Key.
5. ChildProtect calculates a signature from the request data and the Secret Access Key using the same algorithm you used to calculate the signature you sent in the request.
6. If the signature generated by ChildProtect matches the one you sent in the request, the request is considered authentic. If the comparison fails, the request is discarded, and ChildProtect returns an error response.


### Signing and Authenticating REST Requests

Authentication is the process of proving your identity to the system. Identity is an important factor in ChildProtect access control decisions. Requests are allowed or denied in part based on the identity of the requester. For example, the right to submit new abuse tokens and report of deletion of abuse files from your storages. As a developer, you'll be making requests that invoke these privileges so you'll need to prove your identity to the system by authenticating your requests. This section shows you how.

The ChildProtect REST API uses a custom HTTP scheme based on a keyed-HMAC (Hash Message Authentication Code) for authentication. To authenticate a request, you first concatenate selected elements of the request to form a string. You then use your Secret Access Key to calculate the HMAC of that string. Informally, we call this process "signing the request," and we call the output of the HMAC algorithm the "signature" because it simulates the security properties of a real signature. Finally, you add this signature as a parameter of the request, using the syntax described in this section.

When the system receives an authenticated request, it fetches the Secret Access Key that you claim to have, and uses it in the same way to compute a "signature" for the message it received. It then compares the signature it calculated against the signature presented by the requester. If the two signatures match, then the system concludes that the requester must have access to the Secret Access Key, and therefore acts with the authority of the principal to whom the key was issued. If the two signatures do not match, the request is dropped and the system responds with an error message.

##### Example Authenticated ChildProtect REST Request

```
GET /REST/2/tokens HTTP/1.1
Host: api.childprotect.com
Date: Wed, 30 May 2012 21:05:32 GMT
Authorization: ChildProtect 5061:NyopBoQfJgHLHwncssBjvAlga36Y75/Upr2Qjsvjkno=
```


#### The Authentication Header

The ChildProtect REST API uses the standard HTTP Authorization header to pass authentication information. (The name of the standard header is unfortunate because it carries authentication information, not authorization). Under the ChildProtect authentication scheme, the Authorization header has the following form.

Authorization: ChildProtect AccessKeyId:Signature
Developers are issued an Access Key ID and a Secret Access Key when they register. For request authentication, the AccessKeyId element identifies the secret key that was used to compute the signature, and (indirectly) the developer making the request.

The Signature element is the RFC HMAC-SHA-256 of selected elements from the request, and so the Signature part of the Authorization header will vary from request to request. If the request signature calculated by the system matches the Signature included with the request, then the requester will have demonstrated possession to the Secret Access Key. The request will then be processed under the identity, and with the authority, of the developer to whom the key was issued.

Following is pseudo-grammar that illustrates the construction of the Authorization request header (\n means the Unicode code point U+000A commonly called newline).

Authorization = "ChildProtect" + " " + AccessKeyId + ":" + Signature;

Signature = Base64( HMAC-SHA-256( YourSecretAccessKeyID, UTF-8-Encoding-Of( StringToSign ) ) );

StringToSign = HTTP-Request-Method + "\n" +
	HTTP-Request-URI-Path + "\n" +
	HTTP-Request-Date;


#### Time Stamp Requirement

A valid time stamp (using the HTTP Date header) is mandatory for authenticated requests. Furthermore, the client time-stamp included with an authenticated request must be within 15 minutes of the ChildProtect system time when the request is received. If not, the request will fail with the 403 error status code. The intention of these restrictions is to limit the possibility that intercepted requests could be replayed by an adversary.

Examples of *Date* header:
```
Sun, 06 Nov 1994 08:49:37 GMT  ; RFC 822, updated by RFC 1123
Sunday, 06-Nov-94 08:49:37 GMT ; RFC 850, obsoleted by RFC 1036
Sun Nov  6 08:49:37 1994       ; ANSI C's asctime() format
```


#### Authentication Examples

The examples in this section use non-working credentials in the following table.

AccessKeyId:	9806
SecretAccessKey:	By7FzJaMxdHe7pKP

In the example StringToSigns, formatting is not significant and \n means the Unicode code point U+000A commonly called newline.


##### Example: signing a GET request

This example gets a list of submitted tokens.

Request:
```
GET /REST/2/tokens-submitted HTTP/1.1
Host: api.childprotect.com
Date: Tue, 29 May 2012 17:28:25 GMT
Authorization: ChildProtect 9806:nXc5v4dtLKGCNb2VIEB+r024VyZhl+/oDUlXo5tpmqk=
```

StringToSign:
```
GET\n
/REST/2/tokens-submitted\n
Tue, 29 May 2012 17:28:25 GMT
```

Note that the elements in StringToSign that were derived from the are taken literally, including URL-Encoding and capitalization.
