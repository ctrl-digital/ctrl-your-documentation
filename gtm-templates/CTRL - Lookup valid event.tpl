___INFO___

{
  "type": "MACRO",
  "id": "cvt_temp_public_id",
  "version": 1,
  "securityGroups": [],
  "displayName": "CTRL - Lookup valid event",
  "description": "Returns true or false depending on the documented event and its required parameters.",
  "containerContexts": [
    "SERVER"
  ]
}


___TEMPLATE_PARAMETERS___

[
  {
    "type": "TEXT",
    "name": "eventName",
    "displayName": "Event name parameter",
    "simpleValueType": true,
    "help": "Used as Firestore document name for lookup",
    "valueHint": "Defaults to event_name if not set"
  },
  {
    "type": "GROUP",
    "name": "group1",
    "displayName": "Firestore settings",
    "groupStyle": "ZIPPY_OPEN",
    "subParams": [
      {
        "type": "TEXT",
        "name": "firestoreId",
        "displayName": "Firestore\u0027s project ID",
        "simpleValueType": true,
        "valueValidators": [
          {
            "type": "NON_EMPTY"
          }
        ]
      },
      {
        "type": "TEXT",
        "name": "firestoreCollection",
        "displayName": "Firestore Collection",
        "simpleValueType": true,
        "valueValidators": [
          {
            "type": "NON_EMPTY"
          },
          {
            "type": "REGEX",
            "args": [
              "^[^/]+$"
            ],
            "errorMessage": "Can not contain forward slash ( / )"
          }
        ]
      }
    ]
  }
]


___SANDBOXED_JS_FOR_SERVER___

// Enter your template code here.
const Firestore = require('Firestore');
const log = require('logToConsole');
const JSON = require('JSON');
const Object = require('Object');
const getType = require('getType');
const getAllEventData = require('getAllEventData');

const eventData = getAllEventData();
const firestoreId = data.firestoreId;
const firestoreCollection = data.firestoreCollection;
const event = data.eventName || eventData.event_name;

let validEvent = true;

// Checks events field in Firestore
validEvent = Firestore.read(firestoreCollection + '/events', { projectId: firestoreId })
  .then((result) =>{
    const firestoreData = result.data;
    
    // Extracts the event in mind. If undocumented, return false
    const documentedEvent = firestoreData[event];
    if (!documentedEvent) return false;
    
    // Function to check all required params are received
    const receivedParam = (param) => eventData[param] !== undefined ? true : false;
  
    // Get all required params (array) and validate against received event data.
    const requiredParams = documentedEvent.required_parameters;
    validEvent = requiredParams.every(receivedParam);
  
    return validEvent;
  }, (error) => {if (error.reason != "not_found" ) log(error); return false;});

function fail(msg) {
  log(msg);
  return undefined;
}

return validEvent;


___SERVER_PERMISSIONS___

[
  {
    "instance": {
      "key": {
        "publicId": "logging",
        "versionId": "1"
      },
      "param": [
        {
          "key": "environments",
          "value": {
            "type": 1,
            "string": "debug"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "access_firestore",
        "versionId": "1"
      },
      "param": [
        {
          "key": "allowedOptions",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "projectId"
                  },
                  {
                    "type": 1,
                    "string": "path"
                  },
                  {
                    "type": 1,
                    "string": "operation"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "*"
                  },
                  {
                    "type": 1,
                    "string": "*"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  }
                ]
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "read_event_data",
        "versionId": "1"
      },
      "param": [
        {
          "key": "eventDataAccess",
          "value": {
            "type": 1,
            "string": "any"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  }
]


___TESTS___

scenarios:
- name: Untitled test 1
  code: |-
    const mockData = {
      eventName : '',
      firestoreId: '',
      firestoreCollection: ''
    };

    // Call runCode to run the template's code.
    let variableResult = runCode(mockData);
setup: |-
  mock('getAllEventData', {
    'event_name': 'test_variable_template',
    'test':1,
    'first_page': false,
    'page_location': 'testing',
    'benny_banan' : 1,
    'member': 1,
    'item_name':1,
    'item_price':2
  });


___NOTES___

Created on 11/18/2024, 5:30:45 PM


