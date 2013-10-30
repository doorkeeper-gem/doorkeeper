function(doc) {
  if(doc.resource_owner_id) {
    emit([doc.resource_owner_id], null);
  }
}
