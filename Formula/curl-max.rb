class CurlMax < Formula
  desc "Feature-maximised version of cURL"
  homepage "https://curl.se"
  url "https://curl.se/download/curl-7.83.1.tar.bz2"
  mirror "https://github.com/curl/curl/releases/download/curl-7_83_1/curl-7.83.1.tar.bz2"
  sha256 "f539a36fb44a8260ec5d977e4e0dbdd2eee29ed90fcedaa9bc3c9f78a113bff0"
  license "curl"

  bottle do
    root_url "https://dl.cloudsmith.io/public/homebrew-crypto/homebrew-crypto/raw/files/"
    sha256 arm64_monterey: "38b3f73b8ba6669e425431cac5efb256e7320ce2a7d3fad551356f40cb86a9c6"
  end

  keg_only :provided_by_macos

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "cunit" => :build
  depends_on "libtool" => :build
  depends_on "pkg-config" => :build
  depends_on "boost"
  depends_on "brotli"
  depends_on "c-ares"
  depends_on "jansson"
  depends_on "jemalloc"
  depends_on "libev"
  depends_on "libidn2"
  depends_on "libpsl"
  depends_on "openldap"
  depends_on "openssl@1.1"
  depends_on "rtmpdump"
  depends_on "zstd"

  # Needed for nghttp2
  resource "libevent" do
    url "https://github.com/libevent/libevent/releases/download/release-2.1.12-stable/libevent-2.1.12-stable.tar.gz"
    sha256 "92e6de1be9ec176428fd2367677e61ceffc2ee1cb119035037a27d346b0403bb"
  end

  resource "nghttp2" do
    url "https://github.com/nghttp2/nghttp2/releases/download/v1.47.0/nghttp2-1.47.0.tar.xz"
    sha256 "68271951324554c34501b85190f22f2221056db69f493afc3bbac8e7be21e7cc"

    unless OS.mac?
      patch do
        # Fix: shrpx_api_downstream_connection.cc:57:3: error: array must be initialized with a brace-enclosed initializer
        url "https://gist.githubusercontent.com/iMichka/5dda45fbad3e70f52a6b4e7dfd382969/raw/19797e17926922bdd1ef21a47e162d8be8e2ca65/nghttp2?full_index=1"
        sha256 "0759d448d4b419911c12fa7d5cbf1df2d6d41835c9077bf3accf9eac58f24f12"
      end
    end
  end

  resource "libssh2" do
    url "https://www.libssh2.org/download/libssh2-1.10.0.tar.gz"
    sha256 "2d64e90f3ded394b91d3a2e774ca203a4179f69aebee03003e5a6fa621e41d51"
  end

  resource "libxml2" do
    url "http://xmlsoft.org/sources/libxml2-2.9.12.tar.gz"
    sha256 "c8d6681e38c56f172892c85ddc0852e1fd4b53b4209e7f4ebf17f7e2eae71d92"
  end

  def install
    vendor = libexec/"vendor"
    ENV.prepend_path "PKG_CONFIG_PATH", Formula["openssl@1.1"].opt_lib/"pkgconfig"
    ENV.prepend_path "PKG_CONFIG_PATH", vendor/"lib/pkgconfig"
    ENV.prepend_path "PATH", vendor/"bin"

    resource("libxml2").stage do
      system "./configure", "--disable-dependency-tracking",
                            "--prefix=#{vendor}",
                            "--without-python",
                            "--without-lzma"
      system "make", "install"
    end

    resource("libevent").stage do
      system "./configure", "--disable-dependency-tracking",
                            "--disable-debug-mode",
                            "--prefix=#{vendor}"
      system "make"
      system "make", "install"
    end

    resource("nghttp2").stage do
      # fix for clang not following C++14 behaviour
      # https://github.com/macports/macports-ports/commit/54d83cca9fc0f2ed6d3f873282b6dd3198635891
      inreplace "src/shrpx_client_handler.cc", "return dconn;", "return std::move(dconn);"

      args = %W[
        --prefix=#{vendor}
        --disable-silent-rules
        --disable-examples
        --without-systemd
        --disable-hpack-tools
        --with-boost=#{Formula["boost"].opt_prefix}
        --enable-asio-lib
        --disable-python-bindings
      ]
      # requires thread-local storage features only available in 10.11+
      args << "--disable-threads" if MacOS.version < :el_capitan

      system "./configure", *args
      system "make"
      system "make", "check"
      system "make", "install"
    end

    resource("libssh2").stage do
      system "./configure", "--prefix=#{vendor}",
                            "--disable-debug",
                            "--disable-dependency-tracking",
                            "--disable-silent-rules",
                            "--disable-examples-build",
                            "--with-libz",
                            "--with-libssl-prefix=#{Formula["openssl@1.1"].opt_prefix}"
      system "make", "install"
    end

    args = %W[
      --disable-debug
      --disable-dependency-tracking
      --disable-silent-rules
      --prefix=#{prefix}
      --with-default-ssl-backend=openssl
      --with-ssl=#{Formula["openssl@1.1"].opt_prefix}
      --with-ca-bundle=#{etc}/openssl@1.1/cert.pem
      --with-ca-path=#{etc}/openssl@1.1/certs
      --enable-ares=#{Formula["c-ares"].opt_prefix}
      --with-brotli
      --with-gssapi
      --with-libidn2
      --with-librtmp
      --with-libpsl
      --with-libssh2
    ]
    args << "--disable-ldap" unless OS.mac?

    system "./configure", *args
    system "make", "install"
    system "make", "install", "-C", "scripts"
    libexec.install "scripts/mk-ca-bundle.pl"
  end

  test do
    # Test vendored libraries.
    (testpath/"test.c").write <<~EOS
      #include <event2/event.h>

      int main()
      {
        struct event_base *base;
        base = event_base_new();
        event_base_free(base);
        return 0;
      }
    EOS
    system ENV.cc, "test.c", "-L#{libexec}/vendor/lib",
                   "-I#{libexec}/vendor/include", "-levent", "-o", "test"
    system "./test"

    (testpath/"test2.c").write <<~EOS
      #include <libssh2.h>

      int main(void)
      {
      libssh2_exit();
      return 0;
      }
    EOS

    system ENV.cc, "test2.c", "-L#{libexec}/vendor/lib",
                   "-I#{libexec}/vendor/include", "-lssh2", "-o", "test2"
    system "./test2"

    (testpath/"test3.c").write <<~EOS
      #include <libxml/tree.h>

      int main()
      {
        xmlDocPtr doc = xmlNewDoc(BAD_CAST "1.0");
        xmlNodePtr root_node = xmlNewNode(NULL, BAD_CAST "root");
        xmlDocSetRootElement(doc, root_node);
        xmlFreeDoc(doc);
        return 0;
      }
    EOS
    args = shell_output("#{libexec}/vendor/bin/xml2-config --cflags --libs").split
    args += %w[test3.c -o test3]
    system ENV.cc, *args
    system "./test3"

    # Test vendored executables.
    system libexec/"vendor/bin/nghttp", "-nv", "https://nghttp2.org"

    # Test IDN support.
    ENV.delete("LC_CTYPE")
    ENV["LANG"] = "en_US.UTF-8"
    system bin/"curl", "-L", "www.r??ksm??rg??s.se", "-o", "index.html"
    assert_predicate testpath/"index.html", :exist?,
                     "Failed to download IDN example site!"
    assert_match "www.xn--rksmrgs-5wao1o.se", File.read("index.html")

    # Fetch the curl tarball and see that the checksum matches.
    # This requires a network connection, but so does Homebrew in general.
    filename = (testpath/"test.tar.gz")
    system bin/"curl", "-L", stable.url, "-o", filename
    filename.verify_checksum stable.checksum

    system libexec/"mk-ca-bundle.pl", "test.pem"
    assert_predicate testpath/"test.pem", :exist?, "Failed to generate PEM!"
    assert_predicate testpath/"certdata.txt", :exist?
  end
end
