# MunkiPhD.
# github.com/MunkiPhD
#
# The algorithm works as so:
# add jugglers to the stack
# while stack.count > 0
#		populate the circuits hash with jugglers from the stack based on their current preference
#		sort the jugglers on each circuit based on dot product (and preference to break ties)
#		pop the jugglers that exceed the limit of jugglers on circuits back onto the stack, and move to their next circuit pref
#		repeat


# Calculations
class Calculations
	# used to calculate the dot product between two hashes
	def self.dot_product(hash_one, hash_two)
		(hash_one[:H] * hash_two[:H]) + 
			(hash_one[:P] * hash_two[:P]) +
			(hash_one[:E] * hash_two[:E])
	end
end


# Used for sorting
class Sorter
	# sorts the jugglers on each circuit key based on the dot product of the juggler for that circuit
	def self.circuit_sorter(hash)
		hash.each { |key, jugglers|
			#puts key
			sorted_jugglers = jugglers.sort! { |x,y| 
				# we want to use whichever current circuit preference we're on for said user
				y_score = y[:dot_products][y[:current_pref]].values[0]
			  x_score = x[:dot_products][x[:current_pref]].values[0]

				# if the scores are equal, we need a tie breaker, which in this case is the preference. The lower the preference number,
				# the higher priority the juggler has
				if y_score == x_score
					y[:current_pref] <=> x[:current_pref]
				else
					y_score <=> x_score
				end
				#result = (y[:dot_products][y[:current_pref]].values[0] <=> x[:dot_products][x[:current_pref]].values[0])
			}
		}
	end
end


class Display
	# displays a hash with it's keys and each key's values
	def self.show_hash(hash)
		hash.each { |key, values|
			puts "Key: #{key}"
			puts "Values:"
			puts values
		}
	end


	# formats display in the required format to be output
	def self.final_format(hash)
		# desired output:
		#C2 J6 C2:128 C1:31 C0:188, J3 C2:120 C0:171 C1:31, J10 C0:120 C2:86 C1:21, J0 C2:83 C0:104 C1:17 
		reversed = Hash[hash.to_a.reverse] # need to reverse the order so that we get the correct output
		reversed.each { |circuit, jugglers|
			str = "#{circuit}"
			line = []
			jugglers.each do |juggler|
				substring = " #{juggler[:id]}"
				juggler[:dot_products].each do |key|
					substring += " #{key.keys[0]}:#{key.values[0]}"
				end
				line << substring
			end
			str += line.join(",")
			puts str + "\n"
		}
	end
end



class Popper
	# pops the jugglers that exceed the limit allowed on each circuit
	def self.pop_tails(hash, stack, max_allowed)
		hash.each { |key, jugglers|
			if jugglers.count > max_allowed
				for i in 1..(jugglers.count - max_allowed) do
					popped = jugglers.pop
					#puts "Popped: #{popped}"
					popped[:current_pref] += 1 # increase the current position of the current_pref
					stack.push(popped)
				end
				#jug.push( jugglers.pop(jugglers.count - jugglers_on_circuit_max))
			end	
		}
	end
end


class Inserter
	@@teamless_jugglers = [] # going to use a class variable here for simplicity's sake

	# inserts from the stack back into the hash based on the jugglers current preference order
	def self.insert_into_hash_from_stack(hash, stack)
		#puts "@insert #{Time.now}"

		while (juggler = stack.pop) != nil
			unless juggler[:dot_products][juggler[:current_pref]] == nil
				circuit_key = juggler[:dot_products][juggler[:current_pref]].keys[0]
				hash[circuit_key] << juggler
			else
				# since the juggler has exhausted their preferences, they are added to the teamless jugglers.
				@@teamless_jugglers << juggler
			end
		end
	end

	# writes the teamless jugglers to a file, used for debug purposes
	def self.write_to_file(file_name)
		DataFileWriter.write_array(file_name, @@teamless_jugglers)
	end

	# accessor method to get the jugglers
	def self.get_teamless_jugglers
		return @@teamless_jugglers
	end
end


# class used for writing to the file system
class DataFileWriter
	# will write the contents of an array to the specified file
	def self.write_array(file_name, array)
		File.open(file_name, 'w') { |file|
			array.each do |arr_value|
				str = arr_value.to_s
				str += "\n"
				file.write(str)
			end
		}
	end


	# writes to the file in the desired output format
	def self.write_final_output_file(file_name, hash)
		File.open(file_name, "w") { |file|
			reversed = Hash[hash.to_a.reverse] # need to reverse the order so that we get the correct output
			reversed.each { |circuit, jugglers|
				#C2 J6 C2:128 C1:31 C0:188, J3 C2:120 C0:171 C1:31, J10 C0:120 C2:86 C1:21, J0 C2:83 C0:104 C1:17 
				str = "#{circuit}"
				line = []
				jugglers.each do |juggler|
					substring = " #{juggler[:id]}"
					juggler[:dot_products].each do |key|
						substring += " #{key.keys[0]}:#{key.values[0]}"
					end
					line << substring
				end
				str += line.join(",")
				file.write(str + "\n")
			}
		}
	end

	# generates a file with INSERTS so that it can be used in a database
	def self.write_db_inserts_file(file_name, hash, table_name = "circuit_jugglers")
		File.open(file_name, 'w') { |file|
			hash.each { |circuit, jugglers|
				jugglers.each do |juggler|
					for i in 0..(juggler[:dot_products].count-1) do
						str = "INSERT INTO #{table_name} VALUES('#{juggler[:dot_products][i].keys[0]}', '#{juggler[:id]}',  #{juggler[:dot_products][i].values[0]}, #{i + 1});"
						file.write(str + "\n")
					end
				end
			}
		}
	end
end

class DataFileReader
	# reads the specified data file, putting circuits into the circuits hash and jugglers into the jugglers hash
	def self.read_file(file_name, circuits, jugglers)
		file = File.new(file_name, "r")
		while (line = file.gets)
			split_line = line.split # initial split of the line to get the different values

			if split_line.any? # make sure that the array isn't empty
				entry_type = split_line[0] # gets the entry type, 'C' for circuit, 'J' for juggler
				entry_id = split_line[1] # the ID of the entry, e.g. 'C45', 'J1199'
				values = []

				# iterate over the H, E, and P values and throw them into an array as integers
				for x in 2..4 do
					split_vals = split_line[x]
					val = split_vals.split(":")
					values << Integer(val[1])
				end

				# check to see if it's a circuit and add to the circuits hash if true
				if entry_type == "C"
					circuits[entry_id] = { H: values[0], E: values[1], P: values[2] }
				end

				# check to see if it's a juggler and add to the jugglers hash if true
				if entry_type == "J"
					prefs_string = split_line[5] # this will get the preferred circuits for this juggler
					split_prefs = prefs_string.split(',')	# and this splits it into individual elements
					jugglers[entry_id] = { H: values[0], E: values[1], P: values[2], prefs: split_prefs }
				end
			end
		end
	end
end


class CircuitJugglerCoordinator
	@circuits_hash
	@jugglers_hash
 	@jug
 	@circuits
 	@jugglers_on_circuit_max

	def initialize
		@circuits_hash = Hash.new
		@jugglers_hash = Hash.new
		@jug = []
	end

	#
	# populates the data from the specified file
	#
	def populate_data(file_name)
		# read the data file and split it into two hashes, one for the circuits, one for the jugglers
		DataFileReader.read_file(file_name, @circuits_hash, @jugglers_hash)
		puts "Completed reading file."

		populate_jugglers # create the jugglers stack

		# need to determine the maximum number of jugglers on each team 
		@jugglers_on_circuit_max = (@jugglers_hash.count / @circuits_hash.count)
		
		# going to create a new hash based solely on the keys with empty arrays as values
		@circuits = Hash.new
		@circuits_hash.each { |key, values|
			@circuits[key] = []
		}
	end

  #
	# Assigns jugglers to teams on circuits
	#
	def assign_jugglers_to_teams
		# this is the iterator that continues to add players to the circuit teams while there are still available players
		puts "Assigning jugglers to circuit teams..."
		while @jug.count > 0 do
			run_assignment_algorithm(@circuits, @jug, @jugglers_on_circuit_max)
		end

		# it appears that there are some orphaned jugglers that won't fit onto a team and satisfy the condition
		# where they would do better than someone who is already there
		# therefore, we're just going to go through the shorted teams and add jugglers to them at random off the stack
		#  - since they have no preference, a dot product of the juggler and the circuit is not a valid marker
		#  - since no valid marker, it has no difference who goes where
		puts "Assigning orphaned jugglers to teams..."
		@circuits.each { |key, values|
			while values.count < @jugglers_on_circuit_max do
				values.push Inserter.get_teamless_jugglers.pop
			end
		}
	end


	#
	# Writes the juggler team data to the specified file
	#
	def write_data_to_file(file_name)
		DataFileWriter.write_final_output_file(file_name, @circuits)
	end


	#
	# Displays to the user the sum of the numbers of each juggler ID on the specified circuit team
	#
	def show_sum_of_jugglers_on_circuit(key)
		sum = 0
		@circuits[key].each do |val|
			sum += Integer(val[:id].delete 'J')
		end
		puts "The sum for the ids of the jugglers assigned to C1970: #{sum}"
	end

	private

	#
	# Populates the hash of jugglers
	#
	def populate_jugglers
		@jugglers_hash.each { |key, values|
			circuit_dot_products = []
			# iterate over the order of preference for the circuit
			values[:prefs].each do |circuit_pref|
				circuit = @circuits_hash[circuit_pref]
				circuit_dot_products << { circuit_pref => Calculations.dot_product(values, circuit)}
			end

			@jug << { id: key, dot_products: circuit_dot_products, current_pref: 0 }
		}
		puts "Populated jugglers list"
	end


	#
	# Runs the algorithm created to assign jugglers to circuit teams
	#
	def run_assignment_algorithm(circuits, jug, jugglers_on_circuit_max)
		#puts "===== insert into circuits hash from the stack ======"
		Inserter.insert_into_hash_from_stack(circuits, jug)

		#puts "==== now we need to sort ===="
		Sorter.circuit_sorter(circuits)

		#puts "==== now pop off the tail ends ===="
		Popper.pop_tails(circuits, jug, jugglers_on_circuit_max)
	end
end

coordinator = CircuitJugglerCoordinator.new
coordinator.populate_data("jugglefest.txt")
coordinator.assign_jugglers_to_teams
coordinator.write_data_to_file("data_output.txt")
coordinator.show_sum_of_jugglers_on_circuit("C1970")

# DataFileWriter.write_db_inserts_file('db_queries.txt', circuits) # used to generate an insert file for a DB
