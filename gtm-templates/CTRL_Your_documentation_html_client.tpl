___INFO___

{
  "type": "CLIENT",
  "id": "cvt_temp_public_id",
  "version": 1,
  "securityGroups": [],
  "displayName": "Ctrl your documentation - HTML",
  "brand": {
    "id": "brand_dummy",
    "displayName": ""
  },
  "description": "",
  "containerContexts": [
    "SERVER"
  ]
}


___TEMPLATE_PARAMETERS___

[
  {
    "type": "TEXT",
    "name": "projectId",
    "displayName": "GCP Project",
    "simpleValueType": true
  },
  {
    "type": "TEXT",
    "name": "firestoreCollection",
    "displayName": "Firestore Collection",
    "simpleValueType": true
  },
  {
    "type": "TEXT",
    "name": "endpoint",
    "displayName": "Endpoint",
    "simpleValueType": true
  },
  {
    "type": "CHECKBOX",
    "name": "automaticDocumentation",
    "checkboxText": "Auto document GA4 events",
    "simpleValueType": true,
    "defaultValue": true,
    "subParams": [
      {
        "type": "CHECKBOX",
        "name": "checkForNewParameters",
        "checkboxText": "Check for new parameters to already documented events",
        "simpleValueType": true,
        "defaultValue": true,
        "enablingConditions": [
          {
            "paramName": "automaticDocumentation",
            "paramValue": true,
            "type": "EQUALS"
          }
        ]
      },
      {
        "type": "TEXT",
        "name": "ignoreParameters",
        "displayName": "Ignore these parameters (applicable across all fields)",
        "simpleValueType": true,
        "enablingConditions": [
          {
            "paramName": "checkForNewParameters",
            "paramValue": true,
            "type": "EQUALS"
          }
        ]
      }
    ]
  }
]


___SANDBOXED_JS_FOR_SERVER___

/*
 *  Copyright 2024 CTRL Digital AB
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 */

const Firestore = require('Firestore');
const setResponseBody = require('setResponseBody');
const setResponseStatus = require('setResponseStatus');
const setResponseHeader = require('setResponseHeader');
const returnResponse = require('returnResponse');
const getRequestPath = require('getRequestPath');
const getRequestBody = require('getRequestBody');
const log = require('logToConsole');
const claimRequest = require('claimRequest');
const JSON = require('JSON');
const Object = require('Object');
const templateDataStorage = require('templateDataStorage');
const getTimestampMillis = require('getTimestampMillis');
const Promise = require('Promise');
const getAllEventData = require('getAllEventData');
const isRequestMpv2 = require('isRequestMpv2');
const extractEventsFromMpv2 = require('extractEventsFromMpv2');
const getType = require('getType');

const projectId = data.projectId;
const collection = data.firestoreCollection;

// Get last documentation update and set as template storage.
lastDocumentationUpdate();
// Check if data is available in template storage
const cachedContent = cachedDataExists();

if (getRequestPath() === data.endpoint) {
  claimRequest();
  
  // If the no data is available, fetch new data
  if (!cachedContent) {
    Firestore.query(collection, [], { projectId: projectId, limit: 10000 })
      .then(firestoreData => {
        if (firestoreData) {
          setTemplateStorages(firestoreData); 
          
          let htmlPage = generateHtmlPage(firestoreData);
          
          setResponseBody(htmlPage);
          setResponseStatus(200);
          returnResponse();
        } else {
          log('No data returned from Firestore');
          setResponseStatus(500);
          returnResponse();
        }});
  } else {
    log('Documentation: Read data from cache.');
    
    let htmlPage = generateHtmlPage(cachedContent);
    
    setResponseBody(htmlPage);
    setResponseStatus(200);
    returnResponse();
  }

} else if (getRequestPath() === data.endpoint + '_update') {
  claimRequest();
  const body      = JSON.parse(getRequestBody()),
        eventName = body.event_name;
  Object.delete(body, 'eventName');
  
  data.ignoreParameters.split(',').forEach(parameter => removeKeyFromObject(body, parameter.trim()));
  
  Firestore.write(collection + '/' + eventName, body,{ projectId: projectId })
    .then(() => {
      Firestore.query(collection, [], { projectId: projectId, limit: 10000 })
        .then(firestoreData => {
          setTemplateStorages(firestoreData);
          
          let updatedUndocumentedData;
          firestoreData.forEach(document => document.id.indexOf('undocumented') > -1 ? updatedUndocumentedData = document.data : {});
          
        if(updatedUndocumentedData) {
          Object.delete(updatedUndocumentedData, eventName);
          
          Firestore.write(collection + '/undocumented', updatedUndocumentedData, { projectId: projectId })
            .then(()=> {
              setUpdatedTimestamp(getTimestampMillis());
              returnResponse(200);
            });
        }
        
      });
      setUpdatedTimestamp();
      setResponseBody('Updated ok');
      returnResponse();
    });

  
    
} else if (data.automaticDocumentation && isRequestMpv2()) {
  if (!cachedContent) {
    Firestore.query(collection, [], { projectId: projectId, limit: 10000 })
      .then(firestoreData => {
      
        if (!firestoreData) {
          log('No data returned from Firestore');
          setResponseStatus(500);
          returnResponse();
        } else {
          setTemplateStorages(firestoreData); 
          processAutoDocumentationRequest(firestoreData);        
        }
      });
  } else {
    processAutoDocumentationRequest(cachedContent);
  }
}

function processAutoDocumentationRequest(firestoreData) {
    let request = extractEventsFromMpv2();
    
    request.forEach(event => {
      let newEventName           = event.event_name,
          newEvent               = cleanCustomKeys(event),
          checkForNewParameters  = data.checkForNewParameters,
          documentedEvent        = findEvent(firestoreData, newEventName, false),
          undocumentedEvent      = findEvent(firestoreData, newEventName, true);
      
      if (!documentedEvent && !undocumentedEvent) {
        let dataToWrite = createUndocumentedObject(newEvent, newEventName);
        
        data.ignoreParameters.split(',').forEach(parameter => removeKeyFromObject(dataToWrite, parameter.trim()));
        
        Firestore.write(collection + '/undocumented', dataToWrite, { projectId: projectId, merge: true })
          .then(() => {
            log('Documentation: event added to undocumented list:', newEventName);
            setUpdatedTimestamp();
          });
      } else if (checkForNewParameters && documentedEvent) {
        let newParameters = undocumentedEvent ? hasNewKey(undocumentedEvent, newEvent) : hasNewKey(documentedEvent, newEvent);
        
        if (newParameters) {
          // merge the old data with new
          let mergeData = mergeDocumentedWithNewData(documentedEvent, newEvent);
          let dataToWrite = createUndocumentedObject(mergeData, newEventName);
          
          
          Firestore.write(collection + '/undocumented', dataToWrite, { projectId: projectId, merge: true })
            .then(() => {
              log('Documentation: updated event added to undocumented list:', newEventName);
              setUpdatedTimestamp();
            });
        }
      }
    });
    
    return;
  }

function findEvent(data, eventToCheck, inUndocumented) {
  let foundEvent = false;
  
  if (inUndocumented) {
    let undocumentedData;
    data.forEach(event => event.id.indexOf('undocumented') > -1 ? undocumentedData = event.data : false);
    
    foundEvent = undocumentedData[eventToCheck] ? undocumentedData[eventToCheck] : false;
  } else {
    data.forEach(event => event.id.indexOf(eventToCheck) > -1 ? foundEvent = event.data : false);
  }
  
  return foundEvent;
}

function hasNewKey(documentedObject, undocumentedObject) {
  let originalKeys = getKeysFromEvent(documentedObject, false),
      newKeys = getKeysFromEvent(undocumentedObject, false);
  
  let hasAdditionalKeys = newKeys.some(key => originalKeys.indexOf(key) === -1);
  
  return hasAdditionalKeys;
}

function getKeysFromEvent(event, returnWithValues) {
  let result = returnWithValues ? 
      {
       event_parameters: {},
       item_parameters: {},
       user_properties: {}
      } 
      : [];
  ['event_parameters', 'user_properties', 'item_parameters'].forEach(paramType => {
    if (event[paramType] && getType(event[paramType]) === 'array') {
      event[paramType].forEach(param => {
        if (!param.key) {
          Object.keys(param).forEach(key => {
            if (returnWithValues) {
              result[paramType][key] = param.example;
            } else {
              result.push(key);
            }
          });
        } else {
          if (returnWithValues) {
            result[paramType][param.key] = param.example;
          } else {
            result.push(param.key);
          }
        }
      });
    } else if (getType(event[paramType]) === 'object'){
      Object.keys(event[paramType]).forEach(key => {
        if (returnWithValues) {
          result[paramType][key] = event[paramType][key];
        } else {
          result.push(key);
        }
      });
    }
  });
  return result;
}

function mergeDocumentedWithNewData(documentedEvent, newEvent) {
  let updatedNewEvent = newEvent,
      documentedData  = getKeysFromEvent(documentedEvent, true),
      newEventData    = getKeysFromEvent(newEvent, false);

  Object.entries(documentedData).forEach(array => {
    let scope        = array[0],
        scopeObjects = array[1];
    
    Object.entries(scopeObjects).forEach(scopeArray => {
      let key   = scopeArray[0],
          value = scopeArray[1];
      
      if (newEventData.indexOf(key) !== -1) return;
      updatedNewEvent[scope][key] = value;
    });
  });
  return updatedNewEvent;
}

function createUndocumentedObject(data, eventName) {
  let dataToWrite     = {};
  
  dataToWrite.safe_guard = 'DO NOT REMOVE. GTM requires all Firestore documents to return with atleast one subitem.';
  dataToWrite[eventName] = data;
  
  return dataToWrite;
}

function cleanCustomKeys(object) {
  Object.entries(object).forEach(array => {
    let key = array[0],
        value = array[1];
    const keyContains = (substring) => key.indexOf(substring) > -1;

    if ((keyContains('x-ga') && !keyContains('user_properties')) || keyContains('x-sst') || key === 'event_name') {
      Object.delete(object, key);
    } else if (keyContains('user_properties')) {
      Object.delete(object, key);
      object.user_properties = value;
    } else if (key === 'items') {
      Object.delete(object, key);
      object.item_parameters = value;
    } else if (key !== 'event_parameters') {
      object.event_parameters = object.event_parameters || {};
      object.event_parameters[key] = value;
      Object.delete(object, key);
    }
  });
  
  return object;
}

function removeKeyFromObject(obj, keyToRemove) {
    // Check if the object is an array
    if (getType(obj) === 'array') {
        for (let i = obj.length - 1; i >= 0; i--) {
            if (typeof obj[i] === 'object' && obj[i] !== null) {
                removeKeyFromObject(obj[i], keyToRemove);
            } else if (obj[i].key === keyToRemove) {
                obj.splice(i, 1);
            }
        }
    } else if (getType(obj) === 'object' && obj !== null) {
        for (const key in obj) {
            if (key === keyToRemove) {
                Object.delete(obj, key);
            } else if (typeof obj[key] === 'object') {
                removeKeyFromObject(obj[key], keyToRemove);
            }
        }
    }
}

function setUpdatedTimestamp(timestamp) {
  timestamp = timestamp ? timestamp : getTimestampMillis();
  
  Firestore.write(collection + '/last_modified', { 'updated_at': timestamp },{ projectId: projectId })
    .then(() => {
      templateDataStorage.setItemCopy('lastUpdate', timestamp);
      log('Documentation: Set updated timestamp');
    });
  
  return;
}

function cachedDataExists() {
  let cachedContent  = templateDataStorage.getItemCopy('firestoreData') || {},
      lastFetch      = templateDataStorage.getItemCopy('lastFetched') || 0,
      lastUpdate     = templateDataStorage.getItemCopy('lastUpdate') || 0,
      maxDayOldData  = getTimestampMillis() - (24 * 60 * 60 * 1000);
  
  // Returns false if:
  // - Previous data doesn't exists,
  // - The Firestore data has been updated more recently than last fetch,
  // - More than one day has passed since last fetch (fail safe, if manual update of Firestore Data).
  if (!cachedContent || lastUpdate > lastFetch || maxDayOldData > lastFetch) {
    return false;
  }
  
  return cachedContent;
}

function lastDocumentationUpdate() {
  let poll             = templateDataStorage.getItemCopy('15minPoll') || 0,
      max15MinOldCheck = getTimestampMillis() - 15 * 60 * 1000;
  
  if (max15MinOldCheck > poll) {
    Firestore.read(collection + '/last_modified', { projectId: projectId })
      .then((result) => {
        templateDataStorage.setItemCopy('lastUpdate', result.data.updated_at);
        templateDataStorage.setItemCopy('15minPoll', getTimestampMillis());
    });
  }
}

function setTemplateStorages(firestoreData) {
  let modifiedData;
  firestoreData.forEach(document => document.id.indexOf('last_modified') > -1 ? modifiedData = document.data : { data: { updated_at: 0 } });

  templateDataStorage.setItemCopy('firestoreData', firestoreData);
  templateDataStorage.setItemCopy('lastFetched', getTimestampMillis());
  templateDataStorage.setItemCopy('lastUpdate', modifiedData.updated_at);

  log('Documentation: Firestore data saved to cache.');

  return;
}

function generateHtmlPage(firestoreData) {
  let htmlContent = '<!DOCTYPE html>';

  htmlContent += '<html>';
  htmlContent += '<head>';
  htmlContent += '  <title>CTRL - Tracking documentation</title>';
  htmlContent += '  <style>';
  htmlContent += '    body {';
  htmlContent += '      display: grid;';
  htmlContent += '      grid-template-areas:';
  htmlContent += '        "header header"';
  htmlContent += '        "nav main"';
  htmlContent += '        "footer footer";';
  htmlContent += '      grid-template-columns: 400px 1fr;';
  htmlContent += '      grid-template-rows: 100px 1fr 50px;';
  htmlContent += '      height: 100vh;';
  htmlContent += '      margin: 0;';
  htmlContent += '      font-family: Arial, Helvetica, sans-serif;';
  htmlContent += '    }';
  htmlContent += '    header {';
  htmlContent += '      grid-area: header;';
  htmlContent += '      padding: 10px;';
  htmlContent += '      color: #495057;';
  htmlContent += '      display: flex;';
  htmlContent += '      justify-content: space-between;';
  htmlContent += '      align-items: center;';
  htmlContent += '      box-shadow: 0 2px 4px rgba(0,0,0,0.1);';
  htmlContent += '    }';
  htmlContent += '    nav {';
  htmlContent += '      grid-area: nav;';
  htmlContent += '      background-color: #fff;';
  htmlContent += '      flex: 1;';
  htmlContent += '      display: flex;';
  htmlContent += '      flex-flow: column;';
  htmlContent += '      overflow-y: auto;';
  htmlContent += '      padding: 5px;';
  htmlContent += '      margin: 10px;';
  htmlContent += '    }';
  htmlContent += '    main {';
  htmlContent += '      grid-area: main;';
  htmlContent += '      flex: 1;';
  htmlContent += '      overflow-y: auto;';
  htmlContent += '      padding: 20px;';
  htmlContent += '      margin: 10px;';
  htmlContent += '    }';
  htmlContent += '    table {';
  htmlContent += '      border-collapse: collapse;';
  htmlContent += '      table-layout: fixed;';
  htmlContent += '      width: 100%;';
  htmlContent += '    }';
  htmlContent += '    tr:nth-child(even) {';
  htmlContent += '      background-color: #f9f9f9;';
  htmlContent += '    }';
  htmlContent += '    th, td {';
  htmlContent += '      border: 1px solid #ddd;';
  htmlContent += '      text-align: left;';
  htmlContent += '      padding: 0.5em;';
  htmlContent += '      word-wrap: break-word;';
  htmlContent += '    }';
  htmlContent += '    th {';
  htmlContent += '      background-color: #f2f2f2;';
  htmlContent += '      color: #333;';
  htmlContent += '    }';
  htmlContent += '    dialog {';
  htmlContent += '      width:80%;';
  htmlContent += '    }';
  htmlContent += '    th:nth-child(1) {';
  htmlContent += '      width: 20%;';
  htmlContent += '    }';
  htmlContent += '    th:nth-child(2) {';
  htmlContent += '      width: 5%;';
  htmlContent += '    }';
  htmlContent += '    th:nth-child(3) {';
  htmlContent += '      width: 5%;';
  htmlContent += '    }';
  htmlContent += '    th:nth-child(4) {';
  htmlContent += '      width: 20%;';
  htmlContent += '    }';
  htmlContent += '    th:nth-child(5) {';
  htmlContent += '      width: 35%;';
  htmlContent += '    }';
  htmlContent += '    th:nth-child(6) {';
  htmlContent += '      width: 15%;';
  htmlContent += '    }';
  htmlContent += '    footer {';
  htmlContent += '      grid-area: footer;';
  htmlContent += '      background-color: #333;';
  htmlContent += '      color: #fff;';
  htmlContent += '      justify-content: center;';
  htmlContent += '      display: flex;';
  htmlContent += '    }';

  htmlContent += '    #logo {';
  htmlContent += '      color: #007bff;';
  htmlContent += '      font-size: 24px;';
  htmlContent += '      height: 40%;';
  htmlContent += '      margin-left: 4%;';
  htmlContent += '    }';
  htmlContent += '    #overview-btn, #undocumented-btn, .submit-btn {';
  htmlContent += '      padding: 20px 16px;';
  htmlContent += '      border: none;';
  htmlContent += '      cursor: pointer;';
  htmlContent += '      font-size: 16px;';
  htmlContent += '    }';
  htmlContent += '    #overview-btn, .submit-btn {';
  htmlContent += '      display: flex;';
  htmlContent += '      justify-content: center;';
  htmlContent += '      align-items: center;';
  htmlContent += '    }';
  htmlContent += '    #undocumented-btn {';
  htmlContent += '      background-color: #ffce2e;';
  htmlContent += '      border-radius: 10px;';
  htmlContent += '      visibility: hidden;';
  htmlContent += '    }';
  htmlContent += '    #download-btn {';
  htmlContent += '      border: none;';
  htmlContent += '      cursor: pointer;';
  htmlContent += '      background-color: #fff;';
  htmlContent += '    }';
  htmlContent += '    #overview-btn {';
  htmlContent += '      border-bottom: 2px solid lightgrey;';
  htmlContent += '      background-color: #fff;';
  htmlContent += '    }';
  htmlContent += '    #events {';
  htmlContent += '      list-style: none;';
  htmlContent += '      padding: 0;';
  htmlContent += '      margin: 0;';
  htmlContent += '      overflow-y: auto;';
  htmlContent += '      flex-flow: column;';
  htmlContent += '    }';
  htmlContent += '    #events li {  ';
  htmlContent += '      margin: 15px;';
  htmlContent += '      padding: 10px;';
  htmlContent += '      background-color: #e9ecef;';
  htmlContent += '      border: 1px solid #dee2e6;';
  htmlContent += '      border-radius: 5px;';
  htmlContent += '      cursor: pointer;';
  htmlContent += '      transition: background-color 0.3s;';
  htmlContent += '    }';
  htmlContent += '    #events li:hover {';
  htmlContent += '      background-color: #dee2e6;';
  htmlContent += '    }';

  htmlContent += '    .border {';
  htmlContent += '      border: 1px solid #dee2e6;';
  htmlContent += '      border-radius: 10px;';
  htmlContent += '    }';
  htmlContent += '    .header-btns {';
  htmlContent += '      display: flex;';
  htmlContent += '      justify-content: center;';
  htmlContent += '      align-items: center;';
  htmlContent += '      gap: 10px;';
  htmlContent += '    }';
  htmlContent += '    .submit-btn {';
  htmlContent += '      border-top: 2px solid lightgrey;';
  htmlContent += '      margin-top: auto;';
  htmlContent += '      box-shadow: 0 -15px 15px 0px #fff;';
  htmlContent += '      border-radius: 10px;';
  htmlContent += '      background-color: #007bff;';
  htmlContent += '      color: #fff;';
  htmlContent += '      width: 100%;';
  htmlContent += '    }';
  htmlContent += '    .upper-section {';
  htmlContent += '      border-bottom: 2px solid lightgrey;';
  htmlContent += '    }';
  htmlContent += '    .upper-section h2 {';
  htmlContent += '      font-size: 1.5rem;';
  htmlContent += '    }';
  htmlContent += '    .lower-section :is(h1,h2,h3,h4,h5,h6) {';
  htmlContent += '      color: #007bff;';
  htmlContent += '      font-size: 1.5rem;';
  htmlContent += '      border-bottom: 2px solid #dee2e6;';
  htmlContent += '    }';
  htmlContent += '    .update-needed {';
  htmlContent += '      background-color: #ffce2e !important;';
  htmlContent += '    }';
  htmlContent += '  </style>';
  htmlContent += '</head>';
            
  htmlContent += '<body>';
  htmlContent += '  <header>';
  htmlContent += '    <img id="logo" src="https://lh3.googleusercontent.com/u/0/drive-viewer/AKGpihYhEUs0Gzw7ASPv7z6Xjggf7l10tf8arTO_2oiUTxGSG5zpmuAsFCkINM2V5OcNAK1AQbQrmaUjeTgTMuEik6UY4MTP1aYFf3Q=w960-h720-rw-v1">';
  htmlContent += '    <h1>Automated Tracking Documentation</h1>';
  htmlContent += '    <div class="header-btns">';
  htmlContent += '      <button id="undocumented-btn" onclick="showUndocumentedEvents()">Undocumented events</button>';
  htmlContent += '      <button id="download-btn" onclick="downloadFirestoreData()" title="Download all tracking documentation">';
  htmlContent += '      <svg xmlns="http://www.w3.org/2000/svg" width="45px" height="45px" fill="none" viewBox="0 0 24 24">';
  htmlContent += '        <path d="M8 5.00005C7.01165 5.00082 6.49359 5.01338 6.09202 5.21799C5.71569 5.40973 5.40973 5.71569 5.21799 6.09202C5 6.51984 5 7.07989 5 8.2V17.8C5 18.9201 5 19.4802 5.21799 19.908C5.40973 20.2843 5.71569 20.5903 6.09202 20.782C6.51984 21 7.07989 21 8.2 21H15.8C16.9201 21 17.4802 21 17.908 20.782C18.2843 20.5903 18.5903 20.2843 18.782 19.908C19 19.4802 19 18.9201 19 17.8V8.2C19 7.07989 19 6.51984 18.782 6.09202C18.5903 5.71569 18.2843 5.40973 17.908 5.21799C17.5064 5.01338 16.9884 5.00082 16 5.00005M8 5.00005V7H16V5.00005M8 5.00005V4.70711C8 4.25435 8.17986 3.82014 8.5 3.5C8.82014 3.17986 9.25435 3 9.70711 3H14.2929C14.7456 3 15.1799 3.17986 15.5 3.5C15.8201 3.82014 16 4.25435 16 4.70711V5.00005M12 11V17M12 17L10 15M12 17L14 15" stroke="#000000" stroke-width="1" stroke-linecap="round" stroke-linejoin="round"/>';
  htmlContent += '      </svg>';
  htmlContent += '    </button>';
  htmlContent += '    </div>';
  htmlContent += '  </header>';
  htmlContent += '  <nav class="border">';
  htmlContent += '    <button id="overview-btn" onclick="updateContent(`overview`)">Overview</button>';
  htmlContent += '    <ul id="events"></ul>';
  htmlContent += '    <button class="submit-btn" onclick="newEvent()">Submit new event</button>';
  htmlContent += '  </nav>';
  htmlContent += '  <main class="border">';
  htmlContent += '    <div class="upper-section">';
  htmlContent += '      <h2 id="event_name">Overview</h2>';
  htmlContent += '      <p id="event_description">Quisque ut dolor gravida, placerat libero vel, euismod.</p>';
  htmlContent += '    </div>';
  htmlContent += '    <div class="lower-section">';
  htmlContent += '      <h3>Event parameters</h3>';
  htmlContent += '      <p id="event_parameters">Nec dubitamus multa iter quae et nos invenerat.</p>';
  htmlContent += '      <h3>User properties</h3>';
  htmlContent += '      <p id="user_properties">Nec dubitamus multa iter quae et nos invenerat.</p>';
  htmlContent += '      <h3>Item parameters</h3>';
  htmlContent += '      <p id="item_parameters">Nec dubitamus multa iter quae et nos invenerat.</p>';
  htmlContent += '    </div>';
  htmlContent += '  </main>';
  htmlContent += '  <dialog id="formDialog">';
  htmlContent += '      <form onsubmit="submitEvent(event)">';
  htmlContent += '        <h3>Event Name:</h3>';
  htmlContent += '        <input type="text" id="add_event_name" name="add_event_name" required>';
  htmlContent += '        <h3>Description:</h3>';
  htmlContent += '        <textarea id="add_event_description" name="add_event_description" required></textarea>';
  htmlContent += '        <h3>Event parameters:</h3>';
  htmlContent += '        <table id="add_event_parameters">';
  htmlContent += '        <thead><tr><th>Key</th><th>Type</th><th>Required</th><th>Example</th><th>Description</th><th>Action</th></tr></thead><tbody></tbody>';
  htmlContent += '        </table>';
  htmlContent += '        <button type="button" onclick="addTableRow(`add_event_parameters`)">Add parameter</button>';
  htmlContent += '        <h3>User properties:</h3>';
  htmlContent += '        <table id="add_user_properties">';
  htmlContent += '        <thead><tr><th>Key</th><th>Type</th><th>Required</th><th>Example</th><th>Description</th><th>Action</th></tr></thead><tbody></tbody>';
  htmlContent += '        </table>';
  htmlContent += '        <button type="button" onclick="addTableRow(`add_user_properties`)">Add property</button>';
  htmlContent += '        </table>';
  htmlContent += '        <h3>Item parameters:</h3>';
  htmlContent += '        <table id="add_item_parameters">';
  htmlContent += '        <thead><tr><th>Key</th><th>Type</th><th>Required</th><th>Example</th><th>Description</th><th>Action</th></tr></thead><tbody></tbody>';
  htmlContent += '        </table>';
  htmlContent += '        <button type="button" onclick="addTableRow(`add_item_parameters`)">Add parameter</button>';
  htmlContent += '        <br>';
  htmlContent += '        <br>';
  htmlContent += '        <br>';
  htmlContent += '        <button type="submit" class="submit-btn">Submit form</input>';
  htmlContent += '      </form>';
  htmlContent += '  </dialog>';
  htmlContent += '  <footer>';
  htmlContent += '    <p>Made by CTRL Digital</p>';
  htmlContent += '  </footer>';
            
  htmlContent += '<script>';
  htmlContent += 'const response =' + JSON.stringify(firestoreData) + ';';
            
// --------------------------- Show the undocumented button if undocumented events exists -----------------------------
// --------------------------- Also, mark previously documented events for update if applicable -----------------------------
      
  htmlContent += '(function(list, id, updateList) {';
  htmlContent += '  if (Array.isArray(updateList) && updateList.length) {';
  htmlContent += '      document.getElementById("undocumented-btn").style.visibility = "visible";';
  htmlContent += '  }';
  htmlContent += '  list.forEach(eventName => {';
  htmlContent += '    const li = document.createElement("li");';
  htmlContent += '    if (eventName === "last_modified" || eventName === "undocumented" ) {';
  htmlContent += '      return;';
  htmlContent += '    } else {';
  htmlContent += '      li.className = "events-item";';
  htmlContent += '      li.setAttribute("onclick", `updateContent("${eventName}")`);';
  htmlContent += '      if (updateList.includes(eventName)) {'; 
  htmlContent += '        li.className += " update-needed";';
  htmlContent += '        li.setAttribute("title", "Update is needed. Check undocumented data!");';
  htmlContent += '        li.textContent = eventName + " (update available)";';
  htmlContent += '      } else {;';
  htmlContent += '        li.textContent = eventName;';
  htmlContent += '      };';
  htmlContent += '      document.querySelector(id).appendChild(li);';
  htmlContent += '    }';
  htmlContent += '  });';

  let eventList        = [],
      eventListString  = '[',
      updateList       = [],
      updateListString = '[';
      
  firestoreData.forEach(event => {
    let eventName = event.id.replace(collection + '/', '');
    if (eventName === 'undocumented') {
      Object.keys(event.data).forEach(key => {
        if (key !== 'safe_guard') updateList.push(key);
      });
    } else eventList.push(eventName);
  });
  
  eventList.sort().forEach(eventName => eventListString += '"' + eventName + '",');
  updateList.sort().forEach(eventName => updateListString += '"' + eventName + '",');
      
  htmlContent += '})(' + 
    eventListString + 
    '], "#events",' + 
    updateListString +
    ']);';
      
// --------------------------- Download all Firestore data as json -----------------------------
      
  htmlContent += 'function downloadFirestoreData() {';
  htmlContent += '  const jsonData = JSON.stringify(response, null, 2);';
  htmlContent += '  const blob = new Blob([jsonData], { type: "application/json" });';
  htmlContent += '  const link = document.createElement("a");';
  htmlContent += '  link.download = "tracking_documentation.json";';
  htmlContent += '  link.href = URL.createObjectURL(blob);';
  htmlContent += '  document.body.appendChild(link);';
  htmlContent += '  link.click();';
  htmlContent += '  document.body.removeChild(link);';
  htmlContent += '}';
      
// --------------------------- Show the clicked events event, user, and item details -----------------------------
      
  htmlContent += 'function updateContent(eventName) {';
  htmlContent += '  restoreSectionContent();';
  htmlContent += '  if (!eventName) return;';
  htmlContent += '  response.forEach(event => {';
  htmlContent += '    const name = event.id.replace("' + collection +'/", "");';
  htmlContent += '    if (name !== eventName) return;';
  htmlContent += '    const description = event.data.event_description;';
  htmlContent += '    document.getElementById("event_name").innerHTML = name;';
  htmlContent += '    document.getElementById("event_description").innerHTML = description;';
  htmlContent += '    let eventParameters,userProperties,itemParameters,';
  htmlContent += '        table = document.createElement("table");';
  htmlContent += '    table.innerHTML = `<thead><tr><th>Key</th><th>Type</th><th>Required</th><th>Example</th><th>Description</th></tr></thead><tbody></tbody>`;';
  htmlContent += '    if (event.data.event_parameters) {';
  htmlContent += '      let id = "event_parameters",';
  htmlContent += '          element = document.getElementById(id),';
  htmlContent += '          event_table = table.cloneNode(true);';
  htmlContent += '      event_table.setAttribute("id", id);';
  htmlContent += '      element.replaceWith(event_table);';
  htmlContent += '      event.data.event_parameters.forEach(param => {';
  htmlContent += '        addTableRow(id, param);';
  htmlContent += '      });';
  htmlContent += '    } else {';
  htmlContent += '      let id = "event_parameters",';
  htmlContent += '          element = document.getElementById(id),';
  htmlContent += '          p = document.createElement("p");';
  htmlContent += '      p.innerText = "No event parameters documented";';
  htmlContent += '      p.setAttribute("id", id);';
  htmlContent += '      element.replaceWith(p);';
  htmlContent += '    }';
  htmlContent += '    if (event.data.user_properties) {';
  htmlContent += '      let id = "user_properties",';
  htmlContent += '          element = document.getElementById(id),';
  htmlContent += '          user_table = table.cloneNode(true);';
  htmlContent += '      user_table.setAttribute("id", id);';
  htmlContent += '      element.replaceWith(user_table);';
  htmlContent += '      event.data.user_properties.forEach(prop => {';
  htmlContent += '        addTableRow(id, prop);';
  htmlContent += '      });';
  htmlContent += '    } else {';
  htmlContent += '      let id = "user_properties",';
  htmlContent += '          element = document.getElementById(id),';
  htmlContent += '          p = document.createElement("p");';
  htmlContent += '      p.innerText = "No user properties documented";';
  htmlContent += '      p.setAttribute("id", id);';
  htmlContent += '      element.replaceWith(p);';
  htmlContent += '    }';
  htmlContent += '    if (event.data.item_parameters) {';
  htmlContent += '      let id = "item_parameters",';
  htmlContent += '          element = document.getElementById(id),';
  htmlContent += '          item_table = table.cloneNode(true);';
  htmlContent += '      item_table.setAttribute("id", id);';
  htmlContent += '      element.replaceWith(item_table);';
  htmlContent += '      event.data.item_parameters.forEach(param => {';
  htmlContent += '        addTableRow(id, param);';
  htmlContent += '      });';
  htmlContent += '    } else {';
  htmlContent += '      let id = "item_parameters",';
  htmlContent += '          element = document.getElementById(id),';
  htmlContent += '          p = document.createElement("p");';
  htmlContent += '      p.innerText = "No item parameters documented";';
  htmlContent += '      p.setAttribute("id", id);';
  htmlContent += '      element.replaceWith(p);';
  htmlContent += '    }';
  htmlContent += '  });';
  htmlContent += '}';

// --------------------------- Show undocumented events registered in Firestore -----------------------------
      
  htmlContent += 'function showUndocumentedEvents() {';
  htmlContent += '  document.getElementById("event_name").innerHTML = "Undocumented events";';
  htmlContent += '  document.getElementById("event_description").innerHTML = "This section lists all events that have not been documented yet.";';
  htmlContent += '  const lowerSection = document.querySelector(".lower-section");';
  htmlContent += '  lowerSection.innerHTML = "";';
  htmlContent += '  const undocumented_table = document.createElement("table");';
  htmlContent += '  undocumented_table.innerHTML = `';
  htmlContent += '    <thead>';
  htmlContent += '      <tr>';
  htmlContent += '        <th style="width:20%;">Event Name</th>';
  htmlContent += '        <th style="width:60%;">Request data</th>';
  htmlContent += '        <th style="width:5%;">Action</th>';
  htmlContent += '      </tr>';
  htmlContent += '    </thead>';
  htmlContent += '    <tbody id="undocumentedEventsTableBody">';
  htmlContent += '    </tbody>';
  htmlContent += '  `;';
  htmlContent += '  lowerSection.appendChild(undocumented_table);';
  htmlContent += '  const undocumentedEvents = [';
      
  let tableUndocumentedNameList = {};
  firestoreData.forEach(event => {
    let eventName = event.id.replace(collection + '/', '');
    if (eventName !== 'undocumented') return;
    let undocumentedEventData = event.data;
    Object.keys(undocumentedEventData).forEach((tableUndocumentedEventName) => {
      if (tableUndocumentedEventName === 'safe_guard') return;
      tableUndocumentedNameList[tableUndocumentedEventName] = event.data[tableUndocumentedEventName];
        });
      });
      
  Object.entries(tableUndocumentedNameList).forEach(obj => {
    let eventName        = obj[0],
        eventRequestData = obj[1];
        
    htmlContent += '{name:"' + eventName + '", request_data:`' + JSON.stringify(eventRequestData) + '`},';
      });
      
  htmlContent += '  ];';
  htmlContent += '  const tableBody = document.getElementById("undocumentedEventsTableBody");';
  htmlContent += '  undocumentedEvents.forEach(event => {';
  htmlContent += '    if (event.request_data.documented) return;';
  htmlContent += '    const row = document.createElement("tr");';
  htmlContent += '    row.innerHTML = `';
  htmlContent += '      <td>${event.name}</td>';
  htmlContent += '      <td>${event.request_data}</td>';
  htmlContent += '      <td><button type="button" onClick=\'populateFormWithData(${JSON.stringify(event)})\'>Add event</button></td>';
  htmlContent += '    `;';
  htmlContent += '    tableBody.appendChild(row);';
  htmlContent += '  });';
  htmlContent += '};';
      
// --------------------------- Clear the details about the undocumented events and populate the generic structure -----------------------------
      
  htmlContent += 'function restoreSectionContent() {';
  htmlContent += '  const lowerSection = document.querySelector(".lower-section");';
  htmlContent += '  let restoredContent = `';
  htmlContent += '    <h3>Event parameters</h3>';
  htmlContent += '    <p id="event_parameters">No event parameters documented.</p>';
  htmlContent += '    <h3>User properties</h3>';
  htmlContent += '    <p id="user_properties">No user properties documented.</p>';
  htmlContent += '    <h3>Item parameters</h3>';
  htmlContent += '    <p id="item_parameters">No item parameters documented.</p>';
  htmlContent += '  `;';
  htmlContent += '  lowerSection.innerHTML = restoredContent;';
      
  htmlContent += '  const upperSection = document.querySelector(".upper-section");';
  htmlContent += '  restoredContent = `';
  htmlContent += '    <h2 id="event_name">Overview</h3>';
  htmlContent += '    <p id="event_description">An overview of all data available in tracking documentation</p>';
  htmlContent += '  `;';
  htmlContent += '  upperSection.innerHTML = restoredContent;';
  htmlContent += '};';
      
// --------------------------- Open up dialog to add new event to documentation -----------------------------
      
  htmlContent += 'function newEvent() {';
  htmlContent += '  const dialog = document.getElementById("formDialog");';
  htmlContent += '  dialog.showModal();';
  htmlContent += '  dialog.addEventListener("click", function toggle(event) {';
  htmlContent += '    if (!event.target.closest("form") && !event.target.closest(".remove_row")) {';
  htmlContent += '      dialog.removeEventListener("click", toggle);';
  htmlContent += '      dialog.close();';
  htmlContent += '    };';
  htmlContent += '  });';
  htmlContent += '};';
      
// --------------------------- Add table row to the current table (event parameters, user properties, item parameters) for the new event -----------------------------
      
  htmlContent += 'function addTableRow(id, object = undefined) {';
  htmlContent += '  const table = document.getElementById(id).getElementsByTagName("tbody")[0];';
  htmlContent += '  const newRow = table.insertRow(-1);';
  htmlContent += '  let cell = newRow.insertCell(0);';
  htmlContent += '  cell.innerHTML = object?.key || `<input type="text" name="key" required>`;';
  htmlContent += '  cell = newRow.insertCell(1);';
  htmlContent += '  cell.innerHTML = object?.type || `<select type="text" name="type" required>' +
                    '<option value="string">String</option>' +
                    '<option value="integer">Integer</option>' +
                    '<option value="float">Float</option>' +
                    '<option value="boolean">Boolean</option>' +
                    '<option value="timestamp">Timestamp</option>`;';
  htmlContent += '  cell = newRow.insertCell(2);';
  htmlContent += '  cell.innerHTML = object?.required ? "Yes" : ' +
                      'object? "No" : ' + 
                        '`<select type="text" name="required" required>' + 
                          '<option value="No">No</option>' +
                          '<option value="Yes">Yes</option>`;';
  htmlContent += '  cell = newRow.insertCell(3);';
  htmlContent += '  cell.innerHTML = object ? object?.example || "No example added" : `<textarea type="text" name="example">`;';
  htmlContent += '  cell = newRow.insertCell(4);';
  htmlContent += '  cell.innerHTML = object ? object?.description || "No description added" : `<textarea type="text" name="description">`;';
  htmlContent += '  if(!object) {';
  htmlContent += '    cell = newRow.insertCell(5);';
  htmlContent += '    cell.innerHTML = `<button type="button" class="remove_row" onclick="removeParameterRow(this)">Remove</button>`;';
  htmlContent += '  };';
  htmlContent += '};';

// --------------------------- Remove added row to a "submit new event" parameter table -----------------------------

  htmlContent += 'function removeParameterRow(element) {';
  htmlContent += '  const row = element.closest("tr");';
  htmlContent += '  row.remove();';
  htmlContent += '}';
      
// --------------------------- Automatic populate the New Event form with data from an undocumented event -----------------------------
      
  htmlContent += 'function populateFormWithData(data) {';
                    // Clear existing rows in tables
  htmlContent += '  document.querySelector("#add_event_name").innerHTML = "";';
  htmlContent += '  document.querySelector("#add_event_description").innerHTML = "";';
  htmlContent += '  document.querySelector("#add_event_parameters tbody").innerHTML = "";';
  htmlContent += '  document.querySelector("#add_user_properties tbody").innerHTML = "";';
  htmlContent += '  document.querySelector("#add_item_parameters tbody").innerHTML = "";';
                    // Parse the JSON data
  htmlContent += '  data.request_data = JSON.parse(data.request_data);';
                    // Function to create a row in the table
  htmlContent += '  const createRow = (tableId, {key, type, required, example, description}) => {';
  htmlContent += '    const tbody = document.querySelector(`#${tableId} tbody`),';
  htmlContent += '          row = tbody.insertRow(),';
  htmlContent += '          keyCell = row.insertCell(),';
  htmlContent += '          typeCell = row.insertCell(),';
  htmlContent += '          requiredCell = row.insertCell(),';
  htmlContent += '          exampleCell = row.insertCell(),';
  htmlContent += '          descriptionCell = row.insertCell();';
  htmlContent += '          removeRowCell = row.insertCell();';
                    // Populate cells with inputs
  htmlContent += '    keyCell.innerHTML = `<input type="text" name="key" value="${key}" required>`;';
  htmlContent += '    typeCell.innerHTML = `<select name="type" value="${type}" required>' +
                    '<option value="string" ${type === "string" ? "selected" : ""}>String</option>' +
                    '<option value="integer" ${type === "integer" ? "selected" : ""}>Integer</option>' +
                    '<option value="float" ${type === "float" ? "selected" : ""}>Float</option>' +
                    '<option value="boolean" ${type === "boolean" ? "selected" : ""}>Boolean</option>' +
                    '<option value="timestamp" ${type === "timestamp" ? "selected" : ""}>Timestamp</option>' +
                    '</select>`;';
  htmlContent += '    requiredCell.innerHTML = `<select name="required" value="${required}" required>' + 
                    '<option value="No" ${required === "no" ? "selected" : ""}>No</option>' + 
                    '<option value="Yes" ${required === "yes" ? "selected" : ""}>Yes</option></select>`;';
  htmlContent += '    exampleCell.innerHTML = `<textarea name="example">${example}</textarea>`;';
  htmlContent += '    descriptionCell.innerHTML = `<textarea name="description">${description}</textarea>`;';
  htmlContent += '    removeRowCell.innerHTML = `<button type="button" class="remove_row" onclick="removeParameterRow(this)">Remove</button>`;';
  htmlContent += '  };';
  htmlContent += '  document.getElementById("add_event_name").value = data.name;';
  htmlContent += '  document.getElementById("add_event_description").value = getPreviousDocumentation(response,"event_description",data.name,"event_description","");';
  htmlContent += '  Object.entries(data.request_data).forEach(([key, value]) => {';
  htmlContent += '      if (key === "item_parameters" && Array.isArray(value)) {';
  htmlContent += '        value.forEach(item => {';
  htmlContent += '          Object.entries(item).forEach(([itemKey, itemValue]) => {';
  htmlContent += '            createRow("add_item_parameters", { ' +
                              'key: itemKey, ' +
                              'type: getPreviousDocumentation(response,"item_parameters",itemKey,"type","string"), ' +
                              'required: "No", ' +
                              'example: JSON.stringify(itemValue).replace(/(^")|("$)/g,""), ' +
                              'description: getPreviousDocumentation(response,"item_parameters",itemKey,"description","") });';
  htmlContent += '          });';
  htmlContent += '        });';
  htmlContent += '      } else if (key === "user_properties" && typeof value === "object") {';
  htmlContent += '        Object.entries(value).forEach(([propertyKey, propertyValue]) => {';
  htmlContent += '          createRow("add_user_properties", { ' +
                            'key: propertyKey, ' +
                            'type: getPreviousDocumentation(response,"user_properties",propertyKey,"type","string"), ' +
                            'required: "No", ' +
                            'example: JSON.stringify(propertyValue).replace(/(^")|("$)/g,""), ' +
                            'description: getPreviousDocumentation(response,"user_properties",propertyKey,"description","") });';
  htmlContent += '        });';
  htmlContent += '      } else if (key === "event_parameters" && typeof value === "object") {';
  htmlContent += '        Object.entries(value).forEach(([paramKey, paramValue]) => {';
  htmlContent += '          createRow("add_event_parameters", { ' +
                            'key: paramKey, ' +
                            'type: getPreviousDocumentation(response,"event_parameters",paramKey,"type","string"), ' +
                            'required: "No", ' +
                            'example: JSON.stringify(paramValue).replace(/(^")|("$)/g,""), ' +
                            'description: getPreviousDocumentation(response,"event_parameters",paramKey,"description","") });';
  htmlContent += '        });';
  htmlContent += '      }';
  htmlContent += '  });';
  htmlContent += '  newEvent()';
  htmlContent += '}';

// --------------------------- Function to see if event data was previously documented ------------------------
  htmlContent += 'function getPreviousDocumentation(data, scope, event, target, fallback) {';
  htmlContent += '    for (let documentedEvent of data) {';
  htmlContent += '        let eventDetails = documentedEvent.data;';
  htmlContent += '        if (eventDetails.hasOwnProperty(scope)) {';
  htmlContent += '            if (typeof eventDetails[scope] === "string" && eventDetails.event_name === event) return eventDetails[scope];';
  htmlContent += '            for (let details of eventDetails[scope]) {';
  htmlContent += '                if (details.key === event) {';
  htmlContent += '                    return details[target];';
  htmlContent += '                }';
  htmlContent += '            }';
  htmlContent += '        }';
  htmlContent += '    }';
  htmlContent += '    return fallback;';
  htmlContent += '}';

// --------------------------- Write the newly documented event to Firestore and update the tracking documentation ------------------------
      
  htmlContent += 'async function submitEvent(event) {';
  htmlContent += '  event.preventDefault();';
  htmlContent += '  let eventName = document.getElementById("add_event_name").value,';
  htmlContent += '      eventDescription = document.getElementById("add_event_description").value,';
  htmlContent += '      suffixes = {"event":"_parameters", "user":"_properties", "item":"_parameters"},';
  htmlContent += '      formData = { event_name: eventName, event_description: eventDescription };';
  htmlContent += '  Object.entries(suffixes).forEach(([key, value]) => {';
  htmlContent += '    let params = [],';
  htmlContent += '        tableBodyRows = document.getElementById("add_" + key + value).getElementsByTagName("tbody")[0].rows;';
  htmlContent += '    if (!tableBodyRows) return;';
  htmlContent += '    Array.from(tableBodyRows).forEach(row => {';
  htmlContent += '      let key = row.querySelector("input[name=\'key\']").value,';
  htmlContent += '          type = row.querySelector("select[name=\'type\']").value,';
  htmlContent += '          required = row.querySelector("select[name=\'required\']").value === "Yes",';
  htmlContent += '          example = row.querySelector("textarea[name=\'example\']").value,';
  htmlContent += '          description = row.querySelector("textarea[name=\'description\']").value;';
  htmlContent += '      params.push({ key: key, type: type, required: required, example: example, description: description });';
  htmlContent += '    });';
  htmlContent += '    if (!params.length) return;';
  htmlContent += '    formData[key + value] = params;';
  htmlContent += '  });';
  htmlContent += '  try {';
  htmlContent += '    const response = await fetch(document.location.protocol + "//" + document.location.hostname + "' + data.endpoint + '_update", {';
  htmlContent += '      method: "POST",';
  htmlContent += '      headers: { "Content-Type": "application/json" },';
  htmlContent += '      body: JSON.stringify(formData)';
  htmlContent += '    });';
  htmlContent += '    if (!response.ok) throw new Error("Network response was not ok.");';
  htmlContent += '    location.reload()';
  htmlContent += '  } catch (error) {';
  htmlContent += '    console.error("Error:", error);';
  htmlContent += '  }';
  htmlContent += '}';
            
  htmlContent += '</script></body></html>';
  
  return htmlContent;
}


___SERVER_PERMISSIONS___

[
  {
    "instance": {
      "key": {
        "publicId": "read_request",
        "versionId": "1"
      },
      "param": [
        {
          "key": "requestAccess",
          "value": {
            "type": 1,
            "string": "any"
          }
        },
        {
          "key": "headerAccess",
          "value": {
            "type": 1,
            "string": "any"
          }
        },
        {
          "key": "queryParameterAccess",
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
  },
  {
    "instance": {
      "key": {
        "publicId": "return_response",
        "versionId": "1"
      },
      "param": []
    },
    "isRequired": true
  },
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
            "string": "all"
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
                    "string": "read_write"
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
        "publicId": "access_template_storage",
        "versionId": "1"
      },
      "param": []
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
  },
  {
    "instance": {
      "key": {
        "publicId": "access_response",
        "versionId": "1"
      },
      "param": [
        {
          "key": "writeResponseAccess",
          "value": {
            "type": 1,
            "string": "any"
          }
        },
        {
          "key": "writeHeaderAccess",
          "value": {
            "type": 1,
            "string": "specific"
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

scenarios: []


___NOTES___

Created on 12/06/2024, 15:26:25


