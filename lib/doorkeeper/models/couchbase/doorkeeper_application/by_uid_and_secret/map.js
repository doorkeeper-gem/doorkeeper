function(doc) {
  if(doc.type == "doorkeeper_application") {
    emit([doc.id, doc.secret]);
  }
}
