class Boringssl < Formula
  desc "Google fork of OpenSSL"
  homepage "https://boringssl.googlesource.com"
  url "https://boringssl.googlesource.com/boringssl.git",
      :revision => "f18ad089f15c1cb39de8ab21aaa81e472b7dc119"
  version "0.0.0.57" # Fake version so we can update the formula regularly.
  head "https://boringssl.googlesource.com/boringssl.git"

  keg_only :provided_by_osx, <<-EOS.undent
    "Apple provides a deprecated OpenSSL, which conflicts with this.
    It also conflicts with Homebrew's shipped OpenSSL and LibreSSL"
  EOS

  option "without-documentation", "Skip building the documentation."

  depends_on "ninja" => :build
  depends_on "cmake" => :build
  depends_on "go" => :build

  def install
    if build.with? "documentation"
      doc.mkpath
      cd "util" do
        system "go", "build", "doc.go"
        system buildpath/"util/doc", "--config", buildpath/"util/doc.config", "--out", doc
      end
    end

    mkdir "build" do
      system "cmake", "-GNinja", "..", "-DBUILD_SHARED_LIBS=1", *std_cmake_args
      system "ninja"

      # There's no real Makefile as such. We have to handle this manually.
      bin.install "tool/bssl"
      lib.install "crypto/libcrypto.dylib", "ssl/libssl.dylib"
    end
    include.install Dir["include/*"]
  end

  test do
    (testpath/"testfile.txt").write("This is a test file")
    expected_checksum = "91b7b0b1e27bfbf7bc646946f35fa972c47c2d32"
    assert_match expected_checksum, shell_output("#{bin}/bssl sha1sum testfile.txt")
  end
end
