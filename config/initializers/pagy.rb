require "pagy/extras/overflow"

Pagy::DEFAULT[:limit] = 20
Pagy::DEFAULT[:limit_max] = 100
Pagy::DEFAULT[:overflow] = :empty_page

require "pagy/extras/limit"
