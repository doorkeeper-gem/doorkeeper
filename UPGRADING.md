### Database changes:

To support client application specific scope limits, add `scopes` to `oauth_applications`.

```ruby
add_column :oauth_applications, :scopes, :string, null: false, default: ''
```
