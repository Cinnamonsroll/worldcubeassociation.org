# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Person, type: :model do
  let!(:person) { FactoryGirl.create :person_who_has_competed_once }

  it "defines a valid person" do
    expect(person).to be_valid
  end

  context "likely_delegates" do
    it "never competed" do
      person = FactoryGirl.create :person
      expect(person.likely_delegates).to eq []
    end

    it "works" do
      competition = person.competitions.first
      delegate = competition.delegates.first
      expect(person.likely_delegates).to eq [delegate]

      competition2 = FactoryGirl.create :competition, delegates: [delegate], starts: 3.days.ago
      FactoryGirl.create :result, person: person, competitionId: competition2.id
      expect(person.likely_delegates).to eq [delegate]

      new_delegate = FactoryGirl.create :delegate
      competition3 = FactoryGirl.create :competition, delegates: [new_delegate], starts: 2.days.ago
      FactoryGirl.create :result, person: person, competitionId: competition3.id
      expect(person.likely_delegates).to eq [delegate, new_delegate]
    end
  end

  describe "updating the data" do
    let!(:person) { FactoryGirl.create(:person_who_has_competed_once, name: "Feliks Zemdegs", countryId: "Australia") }
    let!(:user) { FactoryGirl.create(:user_with_wca_id, person: person) }

    context "fixing the person" do
      it "fixing countryId fails if there exists an old person with the same wca id, greater subId and the same countryId" do
        Person.create(wca_id: person.wca_id, subId: 2, name: person.name, countryId: "New Zealand")
        person.countryId = "New Zealand"
        expect(person).to be_invalid_with_errors(countryId: ["Cannot change the country to a country the person has already represented in the past."])
      end

      it "updates personName and countryId columns in the results table" do
        person.update_attributes!(name: "New Name", countryId: "New Zealand")
        expect(person.results.pluck(:personName).uniq).to eq ["New Name"]
        expect(person.results.pluck(:countryId).uniq).to eq ["New Zealand"]
      end

      it "doesn't update personName and countryId columns in the results table if they differ from the current ones" do
        FactoryGirl.create(:person_who_has_competed_once, wca_id: person.wca_id, subId: 2, name: "Old Name", countryId: "France")
        person.update_attributes!(name: "New Name", countryId: "New Zealand")
        expect(person.results.pluck(:personName).uniq).to match_array ["Old Name", "New Name"]
        expect(person.results.pluck(:countryId).uniq).to match_array ["France", "New Zealand"]
      end

      it "updates the associated user" do
        person.update_attributes!(name: "New Name", countryId: "New Zealand", dob: "1990-10-10")
        expect(user.reload.name).to eq "New Name"
        expect(user.country_iso2).to eq "NZ"
        expect(user.dob).to eq Date.new(1990, 10, 10)
      end
    end

    context "updating the person using sub id" do
      it "fails if both name and countryId haven't changed" do
        person.update_using_sub_id(name: "Feliks Zemdegs")
        expect(person.errors[:base]).to eq ["The name or the country must be different to update the person."]
      end

      it "fails if both name and countryId haven't been passed" do
        person.update_using_sub_id(dob: "1990-10-10")
        expect(person.errors[:base]).to eq ["The name or the country must be different to update the person."]
      end

      it "doesn't update the results table" do
        person.update_using_sub_id(name: "New Name", countryId: "New Zealand")
        expect(person.results.pluck(:personName).uniq).to eq ["Feliks Zemdegs"]
        expect(person.results.pluck(:countryId).uniq).to eq ["Australia"]
      end

      it "creates a new Person with subId equal to 2 containing the old data" do
        person.update_using_sub_id(name: "New Name", countryId: "New Zealand")
        expect(Person.where(wca_id: person.wca_id, subId: 2, name: "Feliks Zemdegs", countryId: "Australia")).to exist
      end

      it "updates the associated user" do
        person.update_using_sub_id(name: "New Name", countryId: "New Zealand", dob: "1990-10-10")
        expect(user.reload.name).to eq "New Name"
        expect(user.country_iso2).to eq "NZ"
        expect(user.dob).to eq Date.new(1990, 10, 10)
      end
    end

    context "updating country and then fixing name" do
      it "does not affect old results" do
        person.update_using_sub_id!(countryId: "New Zealand")
        person.update_attributes!(name: "Felix Zemdegs")
        expect(person.results.pluck(:personName).uniq).to eq ["Feliks Zemdegs"]
        expect(person.results.pluck(:countryId).uniq).to eq ["Australia"]
      end
    end

    context "updating name and then fixing country" do
      it "does not affect old results" do
        person.update_using_sub_id!(name: "Felix Zemdegs")
        person.update_attributes!(countryId: "New Zealand")
        expect(person.results.pluck(:personName).uniq).to eq ["Feliks Zemdegs"]
        expect(person.results.pluck(:countryId).uniq).to eq ["Australia"]
      end
    end
  end

  describe "#world_championship_podiums" do
    let!(:wc2015) { FactoryGirl.create :competition, championship_types: ["world"], starts: Date.new(2015, 1, 1) }
    let!(:wc2017) { FactoryGirl.create :competition, championship_types: ["world"], starts: Date.new(2017, 1, 1) }
    let!(:result1) { FactoryGirl.create :result, person: person, competition: wc2015, pos: 2, eventId: "333" }
    let!(:result2) { FactoryGirl.create :result, person: person, competition: wc2015, pos: 1, eventId: "333oh" }
    let!(:result3) { FactoryGirl.create :result, person: person, competition: wc2017, pos: 3, eventId: "444" }

    it "return results ordered by year and event" do
      expect(person.world_championship_podiums.to_a).to eq [result3, result1, result2]
    end
  end

  describe "#championship_podiums" do
    let!(:nationals2017) { FactoryGirl.create :competition, championship_types: ["US"], starts: Date.new(2017, 1, 1) }
    let!(:us_competitor) { FactoryGirl.create :person, countryId: "USA" }
    let!(:fr_competitor) { FactoryGirl.create :person, countryId: "France" }
    let!(:us_podium_result) { FactoryGirl.create :result, person: us_competitor, competition: nationals2017, pos: 2, eventId: "333" }
    let!(:fr_podium_result) { FactoryGirl.create :result, person: fr_competitor, competition: nationals2017, pos: 1, eventId: "333" }
    let!(:us_dnf_podium_result) do
      FactoryGirl.create :result, person: us_competitor, competition: nationals2017, pos: 2, eventId: "555bf",
                                  best: SolveTime::DNF_VALUE, average: SolveTime::DNF_VALUE
    end

    context "when a foreiner does compete" do
      it "cannot gain a champion title" do
        expect(fr_competitor.championship_podiums[:national]).to eq []
      end

      it "is ignored when computing others' position" do
        expect(us_competitor.championship_podiums[:national].first.pos).to eq 1
      end
    end

    it "ignores DNF results on the podium" do
      expect(us_competitor.championship_podiums[:national].map(&:eventId)).to eq %w(333)
    end
  end
end
