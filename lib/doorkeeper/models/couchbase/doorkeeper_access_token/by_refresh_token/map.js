function(doc) {
  if(doc.type == "doorkeeper_access_token") {
    emit([doc.refresh_token]);
  }
}
