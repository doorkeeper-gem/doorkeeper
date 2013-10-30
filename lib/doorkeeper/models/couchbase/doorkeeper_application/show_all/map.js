function (doc, meta)
{
  if(doc.type == "doorkeeper_application") {
    emit(null, [doc.name, doc.secret, doc.redirect_uri]);
  }
}