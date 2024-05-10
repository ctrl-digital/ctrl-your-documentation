___INFO___

{
  "type": "MACRO",
  "id": "cvt_temp_public_id",
  "version": 1,
  "securityGroups": [],
  "displayName": "CTRL - Documented event approval",
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
    "displayName": "Event name",
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

let VALID_EVENT = true,
    REQUIRED_PARAMS = [];

VALID_EVENT = Firestore.read(firestoreCollection + '/' + event, {
    projectId: firestoreId,
  }).then((result) =>{
    const firestore_data = result.data;
    validateEvent(firestore_data);
  
    const paramExistsWithValue = (param) => eventData[param] !== undefined ? true : false;
  
    VALID_EVENT = REQUIRED_PARAMS.every(paramExistsWithValue);
  
    return VALID_EVENT;
  }, (error) => {log(error); return false;});

function validateEvent(data) {
  if (getType(data) !== 'object') fail('Firestore response was not an object');
  nestedKeys(data);
  
  function nestedKeys(data) {
    Object.entries(data).forEach((obj)=> {
      let key = obj[0],
          value = obj[1];
      if (getType(value) === 'array') {
        value.forEach(subObj => {
          nestedKeys(subObj);
        });
      }
      
      if (key === 'required' && value) REQUIRED_PARAMS.push(data.key);
      return;
    });
  }
}
function fail(msg) {
  log(msg);
  return undefined;
}

return VALID_EVENT;


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

Created on 27/03/2024, 13:39:34


