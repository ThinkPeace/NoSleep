class Nosleep < Formula
  desc "macOS no-sleep CLI wrapper around caffeinate"
  homepage "https://github.com/ThinkPeace/NoSleep"
  url "https://github.com/ThinkPeace/NoSleep/releases/download/v0.1.3/nosleep-0.1.3"
  sha256 "05aa5fcc3634e52088b8c4b15b033711978ef199129bda2c4fc62d7b5d04fcdb"
  version "0.1.3"

  def install
    bin.install "nosleep-0.1.3" => "nosleep"
  end

  test do
    system "#{bin}/nosleep", "--version"
  end
end
