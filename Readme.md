# CTRL Your Documentation
## Purpose
In GTMS there's two added custom templates:
- CTRL Your Documentation client template
- Validate event variable template

The data for the documentation is stored in Google Cloud's Firestore. Each event is it's own document within a Firestore collection.

If needed, the setup can collect and store previously undocumented events for possible missed documentation. This data will be stored in the document *Undocumented* with the request parameters populated as a subfield for each undocumented event. 
## Setup
The process is 
### Create firebase
### Create client
Start by heading into [[/gtm-templates]] and download the two `.tpl` files.
### Create variable
Start by heading into [[/gtm-templates]] and download the two `.tpl` files.
### Modify 