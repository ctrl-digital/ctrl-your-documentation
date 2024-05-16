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
    "type": "TEXT",
    "name": "automaticDocumentationEndpoint",
    "displayName": "Detect new events on this endpoint",
    "simpleValueType": true,
    "help": "Currently only measure protocol 2"
  }
]


___SANDBOXED_JS_FOR_SERVER___

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

if (getRequestPath() === data.endpoint) {
  claimRequest();

  const cachedContent = templateDataStorage.getItemCopy('firestoreData') || {},
        lastFetch     = templateDataStorage.getItemCopy('lastFetched') || 0,
        maxDayOldData = getTimestampMillis() - (24 * 60 * 60 * 1000);

    Promise.all([
      Promise.create((resolve, reject) => {
        if (!cachedContent || maxDayOldData > lastFetch) {
          resolve(Firestore.query(
            collection, 
            [], 
            { projectId: projectId, limit: 10000 }
          ).then().catch(error => {
            if (getType(error) === 'object') {
              log('Error likely due to a document with a key without value. Populate all documents and keys in Firestore and try again.');
            } else {
              log(error);
            }
          })); 
        } else {
          log('Documentation: Read data from cache.');
          resolve();
        }
      }),
      cachedContent
    ]).then(result => {
      let updatedContent = result[0],
          cachedContent  = result[1];
      if (updatedContent) {
        templateDataStorage.setItemCopy('firestoreData', updatedContent);
        templateDataStorage.setItemCopy('lastFetched', getTimestampMillis());
        log('Documentation: Saved Firestore data to cache.');
      }
      
      let firestoreData = updatedContent || cachedContent,
          htmlContent = '<!DOCTYPE html>';

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
      htmlContent += '      background-color: #E9D502;';
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
      htmlContent += '  </style>';
      htmlContent += '</head>';
            
      htmlContent += '<body>';
      htmlContent += '  <header>';
      htmlContent += '    <div id="logo">Logotype</div>';
      htmlContent += '    <h1>Automated tracking documentation</h1>';
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
      htmlContent += '        <thead><tr><th>Key</th><th>Type</th><th>Required</th><th>Example</th><th>Description</th></tr></thead><tbody></tbody>';
      htmlContent += '        </table>';
      htmlContent += '        <button type="button" onclick="addTableRow(`add_event_parameters`)">Add parameter</button>';
      htmlContent += '        <h3>User properties:</h3>';
      htmlContent += '        <table id="add_user_properties">';
      htmlContent += '        <thead><tr><th>Key</th><th>Type</th><th>Required</th><th>Example</th><th>Description</th></tr></thead><tbody></tbody>';
      htmlContent += '        </table>';
      htmlContent += '        <button type="button" onclick="addTableRow(`add_user_properties`)">Add property</button>';
      htmlContent += '        </table>';
      htmlContent += '        <h3>Item parameters:</h3>';
      htmlContent += '        <table id="add_item_parameters">';
      htmlContent += '        <thead><tr><th>Key</th><th>Type</th><th>Required</th><th>Example</th><th>Description</th></tr></thead><tbody></tbody>';
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
      
      htmlContent += '(function(list, id) {';
      htmlContent += '  list.forEach(eventName => {';
      htmlContent += '    const li = document.createElement("li");';
      htmlContent += '    if (eventName === "undocumented") {';
      htmlContent += '      document.getElementById("undocumented-btn").style.visibility = "visible";';
      htmlContent += '    } else {';
      htmlContent += '      li.className = "events-item";';
      htmlContent += '      li.setAttribute("onclick", `updateContent("${eventName}")`);';
      htmlContent += '      li.textContent = eventName;';
      htmlContent += '      document.querySelector(id).appendChild(li);';
      htmlContent += '    }';
      htmlContent += '  });';

      let eventList       = [],
          eventListString = '[';
      
      firestoreData.forEach(event => {
        let eventName = event.id.replace(collection + '/', '');
        if (eventName === 'undocumented' && Object.keys(event.data).every(key => key === 'safe_guard')) return;
        eventList.push(eventName);
      });
      
      eventList.sort().forEach(eventName => eventListString += '"' + eventName + '",');
      
      htmlContent += '})(' + eventListString + '], "#events");';
      
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
      htmlContent += '      <td><button type="button" onClick=\'populateFormWithData(${JSON.stringify(event.request_data)})\'>Add event</button></td>';
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
      
// --------------------------- Automatic populate the New Event form with data from an undocmented event -----------------------------
      
      htmlContent += 'function populateFormWithData(jsonData) {';
                        // Clear existing rows in tables
      htmlContent += '  document.querySelector("#add_event_parameters tbody").innerHTML = "";';
      htmlContent += '  document.querySelector("#add_item_parameters tbody").innerHTML = "";';
                        // Parse the JSON data
      htmlContent += '  const data = JSON.parse(jsonData);';
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
                        '<option value="string">String</option>' +
                        '<option value="integer">Integer</option>' +
                        '<option value="float">Float</option>' +
                        '<option value="boolean">Boolean</option>' +
                        '<option value="timestamp">Timestamp</option>' +
                        '</select>`;';
      htmlContent += '    requiredCell.innerHTML = `<select name="required" value="${required}" required>' + 
                        '<option value="No">No</option>' + 
                        '<option value="Yes">Yes</option></select>`;';
      htmlContent += '    exampleCell.innerHTML = `<textarea name="example" required>${example}</textarea>`;';
      htmlContent += '    descriptionCell.innerHTML = `<textarea name="description">${description}</textarea>`;';
      htmlContent += '    removeRowCell.innerHTML = `<button type="button" class="remove_row" onclick="removeParameterRow(this)">Remove</button>`;';
      htmlContent += '  };';
                        // Filter out "x-…" fields and populate event parameters
      htmlContent += '  Object.entries(data).forEach(([key, value]) => {';
      htmlContent += '      if (key === "event_name") {';
      htmlContent += '        const name = document.getElementById("add_event_name");';
      htmlContent += '        name.value = value;';
      htmlContent += '      } else if (key === "items" && Array.isArray(value)) {';
      htmlContent += '        value.forEach(item => {';
      htmlContent += '          Object.entries(item).forEach(([itemKey, itemValue]) => {';
      htmlContent += '            createRow("add_item_parameters", { key: itemKey, type: "string", required: "No", example: JSON.stringify(itemValue).replace(/(^")|("$)/g,""), description: "" });';
      htmlContent += '          });';
      htmlContent += '        });';
      htmlContent += '      } else {';
      htmlContent += '        createRow("add_event_parameters", { key: key, type: "string", required: "No", example: JSON.stringify(value).replace(/(^")|("$)/g,""), description: "" });';
      htmlContent += '      }';
      htmlContent += '  });';
      htmlContent += '  newEvent()';
      htmlContent += '}';
      
// --------------------------- Write the newly documented event to Firestore and update the tracking documentation -----------------------------
      
      htmlContent += 'async function submitEvent(event) {';
      htmlContent += '  event.preventDefault();';
      htmlContent += '  let eventName = document.getElementById("add_event_name").value,';
      htmlContent += '      eventDescription = document.getElementById("add_event_description").value,';
      htmlContent += '      suffixes = {"event":"_parameters", "user":"_properties", "item":"_parameters"},';
      htmlContent += '      formData = { event_Name: eventName, event_description: eventDescription };';
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

      
      setResponseBody(htmlContent);
      setResponseStatus(200);
      returnResponse();

    }).catch( error => {
      log('Error', error);
      setResponseStatus(500);
      returnResponse();
    });

} else if (getRequestPath() === data.endpoint + '_update') {
  claimRequest();
  const body      = JSON.parse(getRequestBody()),
        eventName = body.eventName;
  Object.delete(body, 'eventName');
  
  Firestore.write(
    collection + '/' + eventName, 
    body,
    {
      projectId: projectId
    }).then(() => {
    
      Firestore.read(
        collection+ '/undocumented', 
        { projectId: projectId, limit: 10000 }
      ).then(result => {
        const undocumentedData = result;

        let updatedUndocumentedData = undocumentedData.data;
        Object.delete(updatedUndocumentedData, eventName);
        
        // Invalidate old cache to force new fetch of documentation. Preventing loop to register undocumented event.
        templateDataStorage.setItemCopy('lastUndocumentedFetched', getTimestampMillis() - (24 * 60 * 61 * 1000));
        templateDataStorage.setItemCopy('lastFetched', getTimestampMillis() - (24 * 60 * 61 * 1000));
        
        Firestore.write(
          collection + '/undocumented',
          updatedUndocumentedData,
          {
          projectId: projectId  
        }).then(()=>{
          returnResponse(200);
        }, returnResponse(500));
      });
    
      setResponseBody('Updated ok');
      returnResponse();
    });
    
} else if (getRequestPath() === data.automaticDocumentationEndpoint && isRequestMpv2()) {
  const cachedContent = templateDataStorage.getItemCopy('firestoreUndocumentedData') || {},
        lastFetch     = templateDataStorage.getItemCopy('lastUndocumentedFetched') || 0,
        maxDayOldData = getTimestampMillis() - (24 * 60 * 60 * 1000);

  Promise.all([
    Promise.create((resolve, reject) => {
      if (!cachedContent || maxDayOldData > lastFetch) {
        resolve(Firestore.query(collection, [], { projectId: projectId, limit: 10000 })); 
      } else {
        log('Documentation: Read data from cache.');
        resolve();
      }
    }),
    cachedContent
  ]).then(result => {
    let updatedContent = result[0],
        cachedContent  = result[1];
    
    if (updatedContent) {
      templateDataStorage.setItemCopy('firestoreUndocumentedData', updatedContent);
      templateDataStorage.setItemCopy('lastUndocumentedFetched', getTimestampMillis());
      log('Documentation: Firestore data saved to cache.');
    }
    
    let firestoreData    = updatedContent || cachedContent,
        request          = extractEventsFromMpv2(),
        documentedEvents = [];
    
    firestoreData.forEach(documentedEvent => {
      let documentedEventName = documentedEvent.id.replace(collection + '/', '');
      
        if (documentedEventName === 'undocumented') {
          let subEventData = documentedEvent;
          
          Object.keys(subEventData.data).forEach(subEventName => {
            documentedEvents.push(subEventName);
            return;
          });
          return;
        }
        
        documentedEvents.push(documentedEventName);
    });
    
    request.forEach(event => {
      let eventData              = event,
          eventName              = eventData.event_name,
          writeToFirestoreObject = {};

      let undocumentedEvent = documentedEvents.every(alreadyDocumentedEvent => alreadyDocumentedEvent !== eventName);
      
      if (undocumentedEvent) {
        writeToFirestoreObject.safe_guard = 'DO NOT REMOVE. GTM requires all Firestore documents to return with atleast one subitem.';
        writeToFirestoreObject[eventName] = eventData;
        
        Object.keys(writeToFirestoreObject[eventName]).forEach(key => {
          if (key.indexOf('x-ga') > -1 || 
              key.indexOf('x-sst') > -1) {
            Object.delete(writeToFirestoreObject[eventName], key);
          }
        }); 
        
        // Invalidate old cache to force new fetch of documentation. Preventing loop to register undocumented event.
        templateDataStorage.setItemCopy('lastUndocumentedFetched', getTimestampMillis() - (24 * 60 * 61 * 1000));
        templateDataStorage.setItemCopy('lastFetched', getTimestampMillis() - (24 * 60 * 61 * 1000));
        
        Firestore.write(
          collection + '/undocumented', 
          writeToFirestoreObject,
          {
            projectId: projectId,
            merge: true
          }).then(() => {
            log('Event added to undocumented list:', eventName);
          }, () => {});
      }
    });
  });
}


___SERVER_PERMISSIONS___

[
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
  }
]


___TESTS___

scenarios: []


___NOTES___

Created on 16/05/2024, 13:38:26


