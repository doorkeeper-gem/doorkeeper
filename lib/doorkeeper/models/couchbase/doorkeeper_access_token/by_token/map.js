function(doc) {
  if(doc.type == "access_token") {
    emit([doc.token]);
  }
}
