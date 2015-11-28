# Web socket html5 online shooter game

Developers: Lahtyuk A, Koltsov F

### Deploy for windows


1) Make
```sh
$ git clone https://github.com/horror/d2d-shooter_game.git
```

2) Download Railsinstaller from http://railsinstaller.org/ with Ruby 2.0.0 and install

3) Make
```sh
$ cd path/to/app_dir
$ bundle install
```

If you faced to
```sh
Gem::RemoteFetcher::FetchError: SSL_connect returned=1 errno=0 state=SSLv3 read server certificate B: certificate verify failed...
```
Look this guide https://gist.github.com/luislavena/f064211759ee0f806c88

4) Download and install PostrgeSQL for windows from http://www.enterprisedb.com/products-services-training/pgdownload#windows

5) Run migrations
```sh
$ rake db:migrate
```

6) Run app and have fun
```sh
$ rails s -e production
```
If you faced to
```sh
can't activate bcrypt-ruby (~>3.0.0), already activated 3.1.2...make sure all dependencies are added to gemfile...
```
Look this question http://stackoverflow.com/questions/18541062/issues-using-bcrypt-3-0-1-with-ruby2-0-on-windows