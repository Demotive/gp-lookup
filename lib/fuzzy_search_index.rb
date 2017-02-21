require "blurrily/map"

class FuzzySearchIndex
  def initialize(practices:)
    @practices = practices
    @practitioners = practices.flat_map.with_index { |practice, practice_index|
      practice.fetch(:practitioners).map { |practitioner|
        {
          name: practitioner,
          practice_index: practice_index,
        }
      }
    }

    build_haystacks
  end

  def find(search_term, max_results: 10)
    name_results = names_haystack.find(search_term, max_results).map { |index, matches, _weight|
      name = practices.fetch(index).fetch(:name)

      [
        index,
        {
          property: :name,
          value: name,
          matches: trigram_matches(name, search_term),
          score: matches,
        },
      ]
    }

    address_results = addresses_haystack.find(search_term, max_results).map { |index, matches, _weight|
      address = practices.fetch(index).fetch(:location).fetch(:address)

      [
        index,
        {
          property: :address,
          value: address,
          matches: trigram_matches(address, search_term),
          score: matches,
        },
      ]
    }

    practitioner_results = practitioners_haystack.find(search_term, max_results).map { |index, matches, _weight|
      practitioner = practitioners.fetch(index)
      name = practitioner.fetch(:name)

      [
        practitioner.fetch(:practice_index),
        {
          property: :practitioners,
          value: name,
          matches: trigram_matches(name, search_term),
          score: matches,
        },
      ]
    }

    practice_results = Hash.new { |hash, index|
      hash[index] = []
    }

    # zip can't start with an empty array
    results_array = [name_results, address_results, practitioner_results]
    results_array.sort_by! { |x| x.size }.reverse!
    array_result1, array_result2, array_result3 = results_array[0], results_array[1], results_array[2]

    # interleave results so we can get a stable order from sorting
    all_results = array_result1
      .zip(array_result2, array_result3)
      .flatten(1)
      .compact

    all_results.each do |(index, match)|
      result = practice_results[index]
      result.push(match)
    end

    practice_results.map { |(index, results)|
      format_practice_result(
        practices.fetch(index),
        results,
      )
    }.each.with_index.sort_by { |(result, i)|
      scores = result.fetch(:score).values.map { |score| -score }

      [
        scores.min,
        scores,
        i,
      ]
    }.map(&:first).take(max_results)
  end

private
  attr_reader(
    :practices,
    :practitioners,
    :names_haystack,
    :addresses_haystack,
    :practitioners_haystack,
  )

  def build_haystacks
    @names_haystack = Blurrily::Map.new
    practices.each.with_index do |practice, index|
      names_haystack.put(practice.fetch(:name), index)
    end

    @addresses_haystack = Blurrily::Map.new
    practices.each.with_index do |practice, index|
      addresses_haystack.put(practice.fetch(:location).fetch(:address), index)
    end

    @practitioners_haystack = Blurrily::Map.new
    practitioners.each.with_index do |practitioner, index|
      practitioners_haystack.put(practitioner.fetch(:name), index)
    end
  end

  def trigram_matches(term, query)
    # break both term and query into trigrams
    haystack = term.downcase.each_char.each_cons(3)
    needles = query.downcase.each_char.each_cons(3)

    # find all the places where the term matches the query
    indices = haystack
      .with_index
      .select { |trigram, _index| needles.include?(trigram) }
      .flat_map { |_trigram, index| [ index, index + 1, index + 2 ] }
      .sort
      .uniq

    # turn it into [start, end] pairs
    indices
      .slice_when { |a, b| a + 1 != b }
      .map { |list| [ list.first, list.last ] }
  end

  def format_practice_result(practice, results)
    name_result = results.find { |result|
      result.fetch(:property) == :name
    } || {
      matches: [],
      score: 0,
    }

    address_result = results.find { |result|
      result.fetch(:property) == :address
    } || {
      matches: [],
      score: 0,
    }

    practitioners_results = results.select { |result|
      result.fetch(:property) == :practitioners
    }

    practitioners_score = practitioners_results.map { |result|
      result.fetch(:score)
    }.max || 0

    practitioners_list = practitioners_results.map { |result|
      {
        value: result.fetch(:value),
        matches: result.fetch(:matches),
      }
    }

    address = "%{address}, %{postcode}" % {
      address: practice.fetch(:location).fetch(:address),
      postcode: practice.fetch(:location).fetch(:postcode),
    }

    {
      code: practice.fetch(:code),
      name: {
        value: practice.fetch(:name),
        matches: name_result.fetch(:matches),
      },
      address: {
        value: address,
        matches: address_result.fetch(:matches),
      },
      practitioners: practitioners_list,
      score: {
        name: name_result.fetch(:score),
        address: address_result.fetch(:score),
        practitioners: practitioners_score,
      },
    }
  end
end
