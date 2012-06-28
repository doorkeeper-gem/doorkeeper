# ActionView::Base.field_error_proc = Proc.new do |html_tag, instance|
#   if html_tag.match("input")
#     message = (error = instance.error_message).respond_to?(:join) ? error.join(",") : error
#     %(<span class="error">
#         #{html_tag}
#         <span class="help-inline">
#           #{message}
#         </span>
#       </span>
#     ).html_safe
#   else
#     html_tag
#   end
# end
