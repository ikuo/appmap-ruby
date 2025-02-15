require 'rails_spec_helper'

describe 'Rails' do
  rails_versions.each do |rails_version|
    include_context 'rails app', rails_version
    include_context 'rails integration test setup'

    describe 'rspec metadata' do
      let(:appmap_json_files) { Dir.glob("#{tmpdir}/appmap/rspec/*.appmap.json") }

      it 'appmap: false disables recording' do
        test_names = appmap_json_files.map(&File.method(:read)).map(&JSON.method(:parse)).map do |json|
          json['metadata']['name']
        end
        expect(test_names).to include('UsersController GET /users/:login shows the user')
        expect(test_names).to_not include('UsersController GET /users/:login performance test')
      end
    end

    describe 'an API route' do
      describe 'creating an object' do
        let(:appmap_json_file) do
          'Api_UsersController_POST_api_users_with_required_parameters_creates_a_user.appmap.json'
        end

        it 'http_server_request is recorded in the appmap' do
          expect(events).to include(
            hash_including(
              'http_server_request' => hash_including(
                'request_method' => 'POST',
                'normalized_path_info' => '/api/users',
                'path_info' => '/api/users',
                'headers' => hash_including('Content-Type' => 'application/x-www-form-urlencoded')
              ),
              'message' => include(
                hash_including(
                  'name' => 'login',
                  'class' => 'String',
                  'value' => 'alice',
                  'object_id' => Integer
                ),
                hash_including(
                  'name' => 'password',
                  'class' => 'String',
                  'value' => '[FILTERED]',
                  'object_id' => Integer
                )
              )
            )
          )
        end

        it 'http_server_response is recorded in the appmap' do
          expect(events).to include(
            hash_including(
              'http_server_response' => hash_including(
                'status_code' => 201,
                'headers' => hash_including('Content-Type' => 'application/json; charset=utf-8')
              ),
              'return_value' => hash_including('class' => 'Hash', 'object_id' => Integer,
                                               'properties' => include({ 'name' => 'login', 'class' => 'String' }))
            )
          )
        end

        it 'properly captures method parameters in the appmap' do
          expect(events).to include hash_including(
            'event' => 'call',
            'thread_id' => Integer,
            'defined_class' => 'Api::UsersController',
            'method_id' => 'build_user',
            'path' => 'app/controllers/api/users_controller.rb',
            'lineno' => Integer,
            'static' => false,
            'parameters' => include(
              'name' => 'params',
              'class' => 'ActiveSupport::HashWithIndifferentAccess',
              'object_id' => Integer,
              'size' => 1,
              'value' => '{login=>alice}',
              'kind' => 'req'
            ),
            'receiver' => anything
          )
        end

        it 'returns a minimal event' do
          expect(events).to include hash_including(
            'event' => 'return',
            'return_value' => Hash,
            'id' => Integer,
            'thread_id' => Integer,
            'parent_id' => Integer,
            'elapsed' => Numeric
          )
        end

        it 'captures log events' do
          expect(events).to include hash_including(
            'event' => 'call',
            'defined_class' => 'Logger::LogDevice',
            'method_id' => 'write',
            'static' => false
          )
        end

        context 'with an object-style message' do
          let(:appmap_json_file) do
            'Api_UsersController_POST_api_users_with_required_parameters_with_object-style_parameters_creates_a_user.appmap.json'
          end

          it 'message properties are recorded in the appmap' do
            expect(events).to include(
              hash_including(
                'message' => include(
                  hash_including(
                    'name' => 'user',
                    'properties' => [
                      { 'name' => 'login', 'class' => 'String' },
                      { 'name' => 'password', 'class' => 'String' }
                    ]
                  )
                )
              )
            )
          end
        end
      end

      describe 'listing objects' do
        context 'with a custom header' do
          let(:appmap_json_file) do
            'Api_UsersController_GET_api_users_with_a_custom_header_lists_the_users.appmap.json'
          end

          it 'custom header is recorded in the appmap' do
            expect(events).to include(
              hash_including(
                'http_server_request' => hash_including(
                  'headers' => hash_including('X-Sandwich' => 'turkey')
                )
              )
            )
          end
        end
      end
    end

    describe 'a UI route' do
      describe 'rendering a page using a template file' do
        let(:appmap_json_file) do
          'UsersController_GET_users_lists_the_users.appmap.json'
        end

        it 'records the template file' do
          expect(events).to include hash_including(
            'event' => 'call',
            'defined_class' => 'app_views_users_index_html_haml',
            'method_id' => 'render',
            'path' => 'app/views/users/index.html.haml'
          )

          expect(appmap['classMap']).to include hash_including(
            'name' => 'app',
            'children' => include(hash_including(
              'name' => 'views',
              'children' => include(hash_including(
                'name' => 'app_views_users_index_html_haml',
                'children' => include(hash_including(
                  'name' => 'render',
                  'type' => 'function',
                  'location' => 'app/views/users/index.html.haml',
                  'static' => true,
                  'labels' => [ 'mvc.template' ]
                ))
              ))
            ))
          )
          expect(appmap['classMap']).to include hash_including(
            'name' => 'app',
            'children' => include(hash_including(
              'name' => 'views',
              'children' => include(hash_including(
                'name' => 'app_views_layouts_application_html_haml',
                'children' => include(hash_including(
                  'name' => 'render',
                  'type' => 'function',
                  'location' => 'app/views/layouts/application.html.haml',
                  'static' => true,
                  'labels' => [ 'mvc.template' ]
                ))
              ))
            ))
          )
        end
      end

      describe 'rendering a page using a text template' do
        let(:appmap_json_file) do
          'UsersController_GET_users_login_shows_the_user.appmap.json'
        end

        it 'records the normalized path info' do
          expect(events).to include(
            hash_including(
              'http_server_request' => {
                'request_method' => 'GET',
                'path_info' => '/users/alice',
                'normalized_path_info' => '/users/{id}',
                'headers' => {
                  'Host' => 'test.host',
                  'User-Agent' => 'Rails Testing'
                }
              }
            )
          )
        end

        it 'ignores the text template' do
          expect(events).to_not include hash_including(
            'event' => 'call',
            'method_id' => 'render',
            'render_template' => anything
          )

          expect(appmap['classMap']).to_not include hash_including(
            'name' => 'views',
            'children' => include(hash_including(
              'name' => 'ViewTemplate',
              'children' => include(hash_including(
                'name' => 'render',
                'type' => 'function',
                'location' => 'text template'
              ))
            ))
          )
        end

        it 'records and labels view rendering' do
          expect(events).to include hash_including(
            'event' => 'call',
            'thread_id' => Numeric,
            'defined_class' => 'inline_template',
            'method_id' => 'render'
          )

          expect(appmap['classMap']).to include hash_including(
            'name' => 'actionview',
            'children' => include(hash_including(
              'name' => 'ActionView',
              'children' => include(hash_including(
                # Rails 6/5 difference
                'name' => /^(Template)?Renderer$/,
                'children' => include(hash_including(
                  'name' => 'render',
                  'labels' => ['mvc.view']
                ))
              ))
            ))
          )
        end
      end
    end

    next unless rails_version == 7

    describe 'rswag test' do
      let(:appmap_json_file) do
        'Users_api_users_post_user_created_returns_a_201_response.appmap.json'
      end

      it 'includes the rswag framework' do
        expect(appmap['metadata']['frameworks'].map { |f| f['name'] }).to include('rswag')
      end
      it 'records the test status' do
        expect(appmap['metadata'].keys).to include('test_status')
        expect(appmap['metadata']['test_status']).to eq('succeeded')
      end
      it 'records the source location' do
        expect(appmap['metadata']['source_location']).to eq('./spec/requests/users_spec.rb:16')
      end
    end

    describe 'with middleware' do
      let(:appmap_json_file) do
        'Rack_stack_changes_the_response_on_the_index_to_422.appmap.json'
      end

      it 'records the middleware effects' do
        expect(events).to include(
          hash_including(
            'http_server_response' => hash_including(
              'status_code' => 422
            )
          )
        )
      end
    end

    describe 'with sprockets' do
      let(:appmap_json_file) do
        'Rack_stack_can_serve_sprocket_assets.appmap.json'
      end

      it 'records the middleware effects' do
        expect(events).to include(
          hash_including(
            'http_server_response' => hash_including(
              'status_code' => 200,
              'headers' => hash_including(
                'content-type' => 'text/css; charset=utf-8'
              )
            )
          )
        )
      end
    end
  end

  describe 'with default appmap.yml' do
    include_context 'Rails app pg database', 'spec/fixtures/rails6_users_app' unless use_existing_data?
    include_context 'rails integration test setup'

    let(:appmap_json_file) do
      'Api_UsersController_POST_api_users_with_required_parameters_creates_a_user.appmap.json'
    end

    it 'http_server_request is recorded' do
      expect(events).to include(
        hash_including(
          'http_server_request' => hash_including(
            'request_method' => 'POST',
            'path_info' => '/api/users'
          )
        )
      )
    end

    it 'controller method is recorded' do
      expect(events).to include hash_including(
        'defined_class' => 'Api::UsersController',
        'method_id' => 'build_user',
        'path' => 'app/controllers/api/users_controller.rb'
      )
    end
  end
end
