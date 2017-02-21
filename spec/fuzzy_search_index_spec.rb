require "fuzzy_search_index"

RSpec.describe(FuzzySearchIndex, "#find") do
  subject(:index) {
    FuzzySearchIndex.new(
      practices: practices,
    )
  }

  let(:practices) {
    [
      heathcote_medical_centre
    ]
  }

  let(:heathcote_medical_centre) {
    {
      code: "H81070",
      name: "Heathcote Medical Centre",
      location: {
        address: "Heathcote, Autumn Drive, Tadworth, Surrey",
        postcode: "KT20 5TH",
        latitude: "51.294906616210937",
        longitude: "-0.22813686728477478",
      },
      practitioners: heathcote_practitioners,
    }
  }

  let(:heathcote_practitioners) {
    [
      "FP Summers",
      "JQ Autumn",
    ]
  }

  context "with no matches" do
    it "returns an empty array" do
      expect(index.find("xyz")).to eq([])
    end
  end

  context "with one match for the practice name" do
    it "returns one result" do
      expect(index.find("medical")).to eq(
        [
          {
            code: "H81070",
            name: {
              value: "Heathcote Medical Centre",
              matches: [
                [10, 16],
              ],
            },
            address: {
              value: "Heathcote, Autumn Drive, Tadworth, Surrey, KT20 5TH",
              matches: [],
            },
            practitioners: [],
            score: {
              name: 7,
              address: 0,
              practitioners: 0,
            }
          }
        ]
      )
    end
  end

  context "with one match for the address" do
    it "returns one result" do
      expect(index.find("tadworth")).to eq(
        [
          {
            code: "H81070",
            name: {
              value: "Heathcote Medical Centre",
              matches: [],
            },
            address: {
              value: "Heathcote, Autumn Drive, Tadworth, Surrey, KT20 5TH",
              matches: [
                [25, 32],
              ],
            },
            practitioners: [],
            score: {
              name: 0,
              address: 8,
              practitioners: 0,
            }
          }
        ]
      )
    end
  end

  context "with a match for both name and address" do
    it "returns one result" do
      expect(index.find("heathcote")).to eq(
        [
          {
            code: "H81070",
            name: {
              value: "Heathcote Medical Centre",
              matches: [
                [0, 8],
              ],
            },
            address: {
              value: "Heathcote, Autumn Drive, Tadworth, Surrey, KT20 5TH",
              matches: [
                [0, 8],
              ],
            },
            practitioners: [],
            score: {
              name: 10,
              address: 10,
              practitioners: 0,
            }
          }
        ]
      )
    end
  end

  context "with a match for both address and practitioner" do
    it "returns one result" do
      expect(index.find("autumn")).to eq(
        [
          {
            code: "H81070",
            name: {
              value: "Heathcote Medical Centre",
              matches: [],
            },
            address: {
              value: "Heathcote, Autumn Drive, Tadworth, Surrey, KT20 5TH",
              matches: [
                [11, 16],
              ],
            },
            practitioners: [
              {
                value: "JQ Autumn",
                matches: [
                  [3, 8]
                ],
              },
            ],
            score: {
              name: 0,
              address: 6,
              practitioners: 6,
            }
          }
        ]
      )
    end
  end

  context "with one match for practitioner" do
    it "returns one result" do
      expect(index.find("summers")).to eq(
        [
          {
            code: "H81070",
            name: {
              value: "Heathcote Medical Centre",
              matches: [],
            },
            address: {
              value: "Heathcote, Autumn Drive, Tadworth, Surrey, KT20 5TH",
              matches: [],
            },
            practitioners: [
              {
                value: "FP Summers",
                matches: [
                  [3, 9]
                ],
              },
            ],
            score: {
              name: 0,
              address: 1,
              practitioners: 7,
            }
          }
        ]
      )
    end
  end
end
