# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html

resources :people do
    collection do
      get :bulk_edit, :context_menu, :edit_mails, :preview_email, :avatar
      post :bulk_edit, :bulk_update, :send_mails
      delete :bulk_destroy
    end
end

resources :departments do
  member do
    get :autocomplete_for_person
    post :add_people
    delete :remove_person
  end
end

resources :people_settings do
  collection do
    get :autocomplete_for_user
  end
end  
resources :resource
get '/resource', :to => 'resource#show', :as => 'people_resource'

resources :skills do
  collection do
    get :new_category
    post :update_category
  end
end

resources :skills do
  member do
    get :edit_category
    delete :remove_category
  end
end

