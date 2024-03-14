class TedgeMapperC8y < Formula
    desc "thin-edge.io tedge-agent service"
    homepage "https://thin-edge.io/"
    version "0.0.1"
    license "Apache-2.0"
    depends_on "tedge" => :optional
    service do
        run ["#{HOMEBREW_PREFIX}/bin/tedge-mapper", "--config-dir", etc/"tedge", "c8y"]
        keep_alive false
    end
end
