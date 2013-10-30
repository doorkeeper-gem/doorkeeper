function(doc) {
  if(doc.type == "doorkeeper_access_token" && doc.application_id && doc.resource_owner_id) {
    emit([doc.application_id, doc.resource_owner_id], null);
  }
}
