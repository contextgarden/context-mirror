require 'www/lib'

# basic login

class WWW

    def handle_login()
        check_template_file('login','exalogin.htm')
        set('password', '')
        message('Login','')
    end

end
