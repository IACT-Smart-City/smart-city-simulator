% Copyright (C) 2008-2014 EDF R&D

% This file is part of Sim-Diasca.

% Sim-Diasca is free software: you can redistribute it and/or modify
% it under the terms of the GNU Lesser General Public License as
% published by the Free Software Foundation, either version 3 of
% the License, or (at your option) any later version.

% Sim-Diasca is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
% GNU Lesser General Public License for more details.

% You should have received a copy of the GNU Lesser General Public
% License along with Sim-Diasca.
% If not, see <http://www.gnu.org/licenses/>.

% Author: Olivier Boudeville (olivier.boudeville@edf.fr)


% Integration test for the soda deterministic example case.
%
% See also:
%
% - class_SodaVendingMachine.erl
% - class_DeterministicThirstyCustomer.erl
%
-module(smart_city_benchmarking_test).



% For all facilities common to all tests:
-include("test_constructs.hrl").

-spec create_sensors( basic_utils:count() ) -> [ pid() ].
create_sensors( Count ) ->
	create_sensors( Count, _Acc=[] ).

create_sensors( _Count=0, Acc ) ->
	Acc;

create_sensors( Count, Acc ) ->

	SensorName = io_lib:format( "Sensor #~B", [ Count ] ),

	% On average, a machine will hold 200 cans initially:
	InitialValue = 10
		+ class_RandomManager:get_positive_integer_gaussian_value(
			_Mu=30, _Sigma=5.0 ),

	% Any can of this machine will cost anything between 1 euro and 6 euros
	% (bounds included):
	GenerateDataInterval = float( class_RandomManager:get_uniform_value( 6 ) ),

	SVMPid = class_Actor:create_initial_actor( class_Sensor,
					[ SensorName, _SensorLat=10.0, _SensorLong=10.0,
		 			  InitialValue, GenerateDataInterval] ),

	create_sensors( Count-1, [ SVMPid | Acc ] ).

% Runs the test.
%
-spec run() -> no_return().
run() ->

	?test_start,

	% Use default simulation settings (50Hz, batch reproducible):
	SimulationSettings = #simulation_settings{

	  simulation_name = "Sim-Diasca Smart City Integration Test",

	  % Using 100Hz here:
	  tick_duration = 0.01

	  % We leave it to the default specification (all_outputs):
	  % result_specification =
	  %  [ { targeted_patterns, [ {".*",[data_and_plot]} ] },
	  %    { blacklisted_patterns, ["^Second" ] } ]

	  %result_specification = [ { targeted_patterns, [ {".*",data_only} ] } ]

	},


	DeploymentSettings = #deployment_settings{

		computing_hosts = { use_host_file_otherwise_local,
							"sim-diasca-host-candidates.txt" },

		%node_availability_tolerance = fail_on_unavailable_node,

		% We want to embed additionally this test and its specific
		% prerequisites, defined in the Mock Simulators:
		%
		additional_elements_to_deploy = [ { ".", code } ],

		% Note that the configuration file below has not to be declared above as
		% well:
		enable_data_exchanger = { true, [ "soda_parameters.cfg" ] },

		enable_performance_tracker = false

	},


	% Default load balancing settings (round-robin placement heuristic):
	LoadBalancingSettings = #load_balancing_settings{},

	% A deployment manager is created directly on the user node:
	DeploymentManagerPid = sim_diasca:init( SimulationSettings,
							   DeploymentSettings, LoadBalancingSettings ),


	_SVM1 = class_Actor:create_initial_actor( class_Sensor,
		[ _SensorName="Teste", _SensorLat=10.0, _SensorLong=10.0,
		 _InitialValue=20.0, _GenerateDataInterval=10.0 ] ),

	_Sensors = create_sensors( 20 ),

	% We want this test to end once a specified virtual duration elapsed, in
	% seconds:
	SimulationDuration = 150,

	DeploymentManagerPid ! { getRootTimeManager, [], self() },
	RootTimeManagerPid = test_receive(),

	?test_info_fmt( "Starting simulation, for a stop after a duration "
					"in virtual time of ~Bms.", [ SimulationDuration ] ),

	RootTimeManagerPid ! { startFor, [ SimulationDuration, self() ] },

	?test_info( "Waiting for the simulation to end, "
				"since having been declared as a simulation listener." ),

	receive

		simulation_stopped ->
			?test_info( "Simulation stopped spontaneously, "
						"specified stop tick must have been reached." )

	end,

	?test_info( "Browsing the report results, if in batch mode." ),
	class_ResultManager:browse_reports(),

	sim_diasca:shutdown(),

	?test_stop.
